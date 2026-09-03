# Registers the Windows Task Scheduler entry for run-prep.ps1 - the Windows pendant of
# scripts/com.morning-loop.prep.plist.template (launchd).
#
# Copy to scripts/register-prep-task.ps1 (gitignored), fill the FILL line, run once from a normal
# PowerShell (per-user task, no admin needed):
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-prep-task.ps1
#     Get-ScheduledTask -TaskName MorningLoop-Prep        # expect EXACTLY one entry
#
# Triggers: at logon and at session unlock (presence-based: the brief lands when you are actually at
# the machine), plus a weekday 08:00 fallback. run-prep.ps1's plan-file guard makes every
# re-trigger after the first a fast no-op, so firing several times a day is safe and intended.
#
# Remove:  Unregister-ScheduledTask -TaskName MorningLoop-Prep -Confirm:$false
#
# Two entries means two runs racing. If you migrated from an older path or task name,
# unregister the old task before registering this one.

$RunPrep  = "<PATH TO YOUR REPO>\scripts\run-prep.ps1"   # FILL - absolute path, no ~ or relative paths
$TaskName = "MorningLoop-Prep"                          # must match $TaskName inside run-prep.ps1

if (-not (Test-Path $RunPrep)) { throw "run-prep.ps1 not found at $RunPrep - fill the path first" }

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RunPrep`""

$User = "$env:USERDOMAIN\$env:USERNAME"
$Triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn -User $User),
    (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 08:00)
)

# SessionUnlock has no New-ScheduledTaskTrigger switch; build it via the CIM class (StateChange 8).
$Unlock = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler |
    New-CimInstance -ClientOnly -Property @{ Enabled = $true; StateChange = 8; UserId = $User }
$Triggers += $Unlock

# 2h execution limit is a backstop only; run-prep.ps1 kills claude itself after 25 min.
# StartWhenAvailable catches a missed 08:00 when the machine was asleep.
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings `
    -Description "Morning Loop unattended pre-run (read-only /morning --prep + delivery safety net)" -Force | Out-Null

Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State
Write-Host "Registered. Do ONE supervised run first if you have not: powershell -NoProfile -ExecutionPolicy Bypass -File `"$RunPrep`""
