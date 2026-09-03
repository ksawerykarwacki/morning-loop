# Agent-manager unattended pre-run - Windows pendant of run-prep.template.sh (macOS/launchd).
# Runs the read-only SENSE + PLAN half of /morning and writes today's plan file.
# Does NOT dispatch and never performs a never_auto external action - that stays interactive
# (the morning gate). Register it with scripts/register-prep-task.template.ps1.
#
# Copy to scripts/run-prep.ps1 (gitignored), fill the FILL lines, then do ONE supervised run:
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-prep.ps1; "exit $LASTEXITCODE"
# before you hand it to Task Scheduler. See scripts/SETUP-DELIVERY.md, "Scheduling the run (Windows)".
#
# Exit codes (Task Scheduler shows them as "Last Run Result"; a health check reads them):
#   0   plan written and brief delivered (or a re-trigger that found both already done)
#   2   another run-prep.ps1 is still running for today - skipped, no race
#   3   claude ran but wrote no plan file
#   4   plan written but the brief never reached a channel
#   10  VPN never came up - nothing attempted (task-level retry takes over)
#   124 claude killed by this script after the 25-minute timeout

# ---------------------------------------------------------------------------------------------
# FILL: absolute paths only. Task Scheduler runs with a minimal environment and no profile.
# ---------------------------------------------------------------------------------------------
$WorkDir    = "<PATH TO YOUR REPO>"                                   # FILL - clone or workspace root
$Claude     = "$env:USERPROFILE\.local\bin\claude.exe"                # FILL if claude lives elsewhere
$TaskName   = "MorningLoop-Prep"                                      # must match register-prep-task.ps1
$PlanDir    = "$WorkDir\01-sprint-operations\current"                 # where /morning --prep writes morning-plan-YYYY-MM-DD.md
$Automation = "$WorkDir\05-automation\agent-manager"                  # receipts, notifier, log live here
$Log        = "$Automation\taskscheduler.log"
$Notifier   = "$Automation\scripts\notify.py"
$Python     = "python"                                                # FILL if python is not on the task's PATH

# Optional VPN gate. Internal MCP sources (Jira/Confluence on a lab network) may only resolve
# inside a VPN. Leave both empty to skip the check entirely.
$VpnProbeHost = ""      # e.g. "gitlab.example.lab" - a hostname that only resolves on VPN
$VpnProfile   = ""      # e.g. "Office VPN" - the rasdial profile name to reconnect with

# ---------------------------------------------------------------------------------------------

Set-Location $WorkDir
New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
Add-Content -Path $Log -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') starting /morning --prep ====="

# Lock file. A scheduled trigger and a manual /morning --prep both call this script and both
# target the same day's plan file, run-log and delivery receipt. Whichever invocation gets here
# first wins; the other exits with 2. A lock whose PID is gone is stale and gets cleared.
$LockFile = "$Automation\.prep.lock"
if (Test-Path $LockFile) {
    $LockData = Get-Content $LockFile -Raw | ConvertFrom-Json
    if (Get-Process -Id $LockData.pid -ErrorAction SilentlyContinue) {
        Add-Content -Path $Log -Value "LOCK: another run-prep.ps1 (PID $($LockData.pid), started $($LockData.started)) is already running - exiting without racing"
        Add-Content -Path $Log -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') finished (exit 2 - concurrent run skipped) ====="
        exit 2
    }
    Add-Content -Path $Log -Value "LOCK: stale lock from PID $($LockData.pid) (process no longer running) - clearing and continuing"
}
@{ pid = $PID; started = (Get-Date -Format 'o') } | ConvertTo-Json | Set-Content -Path $LockFile

try {

$Today       = Get-Date -Format 'yyyy-MM-dd'
$PlanFile    = "$PlanDir\morning-plan-$Today.md"
$ReceiptFile = "$Automation\delivery-receipts\$Today.json"
$ExitCode    = $null

if (Test-Path $PlanFile) {
    # Presence-based triggers (AtLogOn + SessionUnlock) fire many times a day. Sense+plan already
    # ran once today: do not re-run it (it would re-hit Jira/Confluence for nothing and could
    # overwrite a plan file you are already acting on). Only the idempotent delivery check below runs.
    Add-Content -Path $Log -Value "SKIP: plan file for $Today already exists - re-trigger, not re-running sense+plan"
    $ExitCode = 0
} else {

# Boundary lines: if the wrapper ever dies silently (Task Scheduler reports 0xC000013A with no
# further log output), the last boundary line pinpoints the statement. Cheap; keep them.
Add-Content -Path $Log -Value "  [boundary] pre-VPN-check"

function Test-Vpn {
    if (-not $VpnProbeHost) { return $true }
    try { [System.Net.Dns]::GetHostAddresses($VpnProbeHost) | Out-Null; return $true }
    catch { return $false }
}

if (-not (Test-Vpn)) {
    Add-Content -Path $Log -Value "VPN down at start - trying rasdial reconnect"
    if ($VpnProfile) { rasdial $VpnProfile 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8 }
    $tries = 0
    while (-not (Test-Vpn) -and $tries -lt 12) { Start-Sleep -Seconds 100; $tries++ }   # ~20 min
    if (-not (Test-Vpn)) {
        Add-Content -Path $Log -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') finished (exit 10 - VPN still down after ~20 min, task retry will re-attempt) ====="
        exit 10
    }
    Add-Content -Path $Log -Value "VPN up after $tries wait cycle(s) - continuing"
}

Add-Content -Path $Log -Value "  [boundary] post-VPN-check, pre-claude-launch"

# --print: headless single-shot. acceptEdits lets it write the plan file without a prompt.
# Force UTF-8 so claude's output does not land as mojibake in the log.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$TmpOut = "$Automation\claude-prep-out.tmp"
$TmpErr = "$Automation\claude-prep-err.tmp"

# Self-identify. routine_health sweeps Get-ScheduledTask and sees this very task as
# State=Running with LastRunTime = now, which looks like a competing instance to a model that
# knows about past race incidents. Tell it that only a LOCK line in the log is a real race.
$PrepPrompt = '/morning --prep' +
  ' [SCHEDULED RUN] You are executing INSIDE the Windows scheduled task' +
  " $TaskName (wrapper PID $PID, started $(Get-Date -Format 'HH:mm:ss'))." +
  ' During routine_health that task WILL show State=Running with LastRunTime = this run.' +
  ' That is you. Never abort, wait, or skip because of it. Only a SECOND run-prep wrapper' +
  ' (a LOCK line in taskscheduler.log) is a real race.'

$p = Start-Process -FilePath $Claude `
    -ArgumentList @('--print', "`"$PrepPrompt`"", '--permission-mode', 'acceptEdits') `
    -NoNewWindow -PassThru -RedirectStandardOutput $TmpOut -RedirectStandardError $TmpErr

Add-Content -Path $Log -Value "  [boundary] claude launched, PID=$($p.Id), entering WaitForExit"

# Use the Process object's own WaitForExit(), not Wait-Process: Wait-Process polls externally and
# does not update the object's exited state, so ExitCode can silently read 0 regardless of the result.
try {
    $finished = $p.WaitForExit(1500000)   # 25 min; the task's execution-time limit is backstop only
    if (-not $finished) {
        Stop-Process -Id $p.Id -Force
        Add-Content -Path $Log -Value "claude killed by script after 25-min timeout (likely hang - check network/MCP sources)"
        $ExitCode = 124
    } else {
        $ExitCode = $p.ExitCode
    }
} catch {
    Add-Content -Path $Log -Value "  [boundary] EXCEPTION during WaitForExit: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    throw
}

Add-Content -Path $Log -Value "  [boundary] WaitForExit returned, ExitCode=$ExitCode"

Get-Content $TmpOut, $TmpErr -ErrorAction SilentlyContinue | Out-File -FilePath $Log -Append -Encoding utf8
Remove-Item $TmpOut, $TmpErr -Force -ErrorAction SilentlyContinue

}

# ---------------------------------------------------------------------------------------------
# DELIVERY SAFETY NET (RUN-AND-NOTIFY.md). Phase 2b should deliver the brief itself; this block
# does not trust that. If today has no "sent" receipt, deliver here. Idempotent: notify.py reuses
# today's brief id, so a brief already delivered is never delivered twice.
#
# Channel + webhook come from the same untracked file the macOS runner sources:
#   %USERPROFILE%\.config\morning-loop\notify.env   (lines like: export MORNING_NOTIFY_CHANNEL=mattermost)
# The webhook is a credential; never inline it here, this script may be committed.
# ---------------------------------------------------------------------------------------------
$NotifyEnv = "$env:USERPROFILE\.config\morning-loop\notify.env"
if (Test-Path $NotifyEnv) {
    Get-Content $NotifyEnv | ForEach-Object {
        $line = $_.Trim() -replace '^export\s+', ''
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            Set-Item -Path "Env:$($Matches[1])" -Value ($Matches[2].Trim([char]34, [char]39))
        }
    }
}
$Channel = if ($env:MORNING_NOTIFY_CHANNEL) { $env:MORNING_NOTIFY_CHANNEL } else { "file" }
if ($Channel -eq "macos") { $Channel = "file" }   # no notification center here; the toast below covers it

$AlreadySent = (Test-Path $ReceiptFile) -and ((Get-Content $ReceiptFile -Raw | ConvertFrom-Json).status -eq "sent")

if ((Test-Path $PlanFile) -and -not $AlreadySent) {
    Add-Content -Path $Log -Value "DELIVER: no sent receipt for $Today - running notify.py as safety net (channel=$Channel)"
    if ($Channel -eq "mattermost" -and -not $env:MORNING_MATTERMOST_WEBHOOK) {
        Add-Content -Path $Log -Value "DELIVER: MORNING_MATTERMOST_WEBHOOK not set in $NotifyEnv - falling back to channel=file"
        $Channel = "file"
    }
    $NotifyArgs = @($Notifier, '--brief', $PlanFile, '--date', $Today, '--channel', $Channel)
    if ($Channel -eq "mattermost") { $NotifyArgs += @('--webhook', $env:MORNING_MATTERMOST_WEBHOOK) }
    & $Python @NotifyArgs 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8

    # NOTIFY: one-line Windows toast, the pendant of the macOS notification-center call.
    # WinForms NotifyIcon needs no install, only .NET (built in). Failure here is logged, not fatal:
    # the brief is already delivered by the time we get here.
    if (Test-Path $ReceiptFile) {
        try {
            $Receipt = Get-Content $ReceiptFile -Raw | ConvertFrom-Json
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            $Toast = New-Object System.Windows.Forms.NotifyIcon
            $Toast.Icon = [System.Drawing.SystemIcons]::Information
            $Toast.Visible = $true
            $Counts = $Receipt.counts
            $Toast.BalloonTipTitle = "Morning Brief #$($Receipt.brief_id)"
            $Toast.BalloonTipText  = "$($Counts.drafts) to draft . $($Counts.asks) asks . $($Counts.your_turn) your turn`nTop: $($Receipt.top)"
            $Toast.ShowBalloonTip(15000)
            Start-Sleep -Seconds 2
            $Toast.Dispose()
            Add-Content -Path $Log -Value "NOTIFY: Windows toast shown for brief #$($Receipt.brief_id)"
        } catch {
            Add-Content -Path $Log -Value "NOTIFY: toast failed ($_) - brief was still delivered, see receipt"
        }
    }
} elseif ($AlreadySent) {
    Add-Content -Path $Log -Value "DELIVER: already sent for $Today, skipping (idempotent)"
} else {
    Add-Content -Path $Log -Value "DELIVER: no plan file for $Today - claude run likely failed before writing it"
}

# Derive the exit code from the DELIVERABLE, not from the process. Start-Process -PassThru can
# return a Process whose ExitCode reads null, and exiting with null becomes 0x0, which makes Task
# Scheduler and any health check record a total failure as "OK". Health checks the END result.
$PlanOk = Test-Path $PlanFile
$SentOk = (Test-Path $ReceiptFile) -and ((Get-Content $ReceiptFile -Raw | ConvertFrom-Json).status -eq "sent")
if ($null -eq $ExitCode) { $ExitCode = 0 }
if     (-not $PlanOk) { $ExitCode = 3 }   # claude ran but wrote no plan file
elseif (-not $SentOk) { $ExitCode = 4 }   # plan written but brief never delivered
Add-Content -Path $Log -Value "RESULT: plan_file=$PlanOk delivered=$SentOk -> exit $ExitCode"
Add-Content -Path $Log -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') finished (exit $ExitCode) ====="
exit $ExitCode

} finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
