#!/usr/bin/env python3
"""
Get the morning brief in front of you with NO account setup.

A delivery step that requires an account is a step most people never complete,
and an undelivered brief is worth the same as no loop at all. So both channels
here cost nothing to set up.

Channels, cheapest first:

  macos       Native notification + the brief opens as a local web page.
              Zero setup. Nothing to sign up for. Works offline.
  mattermost  One incoming-webhook URL pasted into a config. No account, no
              2FA, no MCP. The squad already lives there. This is the one to
              share.
  file        Render the HTML and do nothing else (for scheduled runs where you
              only want the artifact).

Usage:
  notify.py --brief <plan.md> [--channel macos|mattermost|file] [--date Y-M-D]
            [--webhook URL] [--no-open] [--dry-run]

Exit: 0 delivered · 2 config error · 3 delivery failed
A receipt is ALWAYS written, so HEALTH can tell "failed" from "never attempted".
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
INDEX = REPO / "05-automation/agent-manager/brief-index.json"
RECEIPTS = REPO / "05-automation/agent-manager/delivery-receipts"
RENDER_DIR = REPO / "05-automation/agent-manager/briefs"


def die(code: int, msg: str, receipt: dict | None = None) -> None:
    """Fail loudly AND leave a receipt. A failure with no artifact is
    indistinguishable from never having run, which is the whole bug class this
    loop exists to avoid."""
    print(f"notify: {msg}", file=sys.stderr)
    if receipt is not None:
        write_receipt(receipt | {"status": "failed", "error": msg})
    raise SystemExit(code)


# --------------------------------------------------------------------------- brief id
def load_index() -> dict:
    if INDEX.exists():
        try:
            return json.loads(INDEX.read_text())
        except json.JSONDecodeError:
            print("notify: brief-index.json is corrupt, starting a new one", file=sys.stderr)
    return {"next_id": 1, "briefs": {}}


def assign_id(idx: dict, date: str, brief_path: str, subject: str) -> int:
    """Same date always maps to the same id, so a re-delivery never burns a number."""
    for bid, rec in idx["briefs"].items():
        if rec.get("date") == date:
            return int(bid)
    bid = idx["next_id"]
    idx["briefs"][str(bid)] = {
        "id": bid, "date": date, "plan_file": brief_path, "subject": subject,
    }
    idx["next_id"] = bid + 1
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(idx, indent=2) + "\n")
    return bid


def write_receipt(rec: dict) -> None:
    RECEIPTS.mkdir(parents=True, exist_ok=True)
    (RECEIPTS / f"{rec['date']}.json").write_text(json.dumps(rec, indent=2) + "\n")


# --------------------------------------------------------------------------- md -> html
CODE_SPAN = re.compile(r"`([^`]+)`")
INLINE = [
    (re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)"), r'<a href="\2">\1</a>'),
    (re.compile(r"\*\*([^*]+)\*\*"), r"<strong>\1</strong>"),
    (re.compile(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])"), r"<em>\1</em>"),
    # underscore emphasis, but never inside a word so snake_case survives
    (re.compile(r"(?<![\w_])_([^_\n]+)_(?![\w_])"), r"<em>\1</em>"),
]


def inline(text: str) -> str:
    """Code spans are extracted BEFORE the emphasis rules run, otherwise markup
    inside them gets mangled (mcp__*Atlassian* turning into an <em>)."""
    out = html.escape(text, quote=False)

    stash: list[str] = []

    def park(m: re.Match) -> str:
        stash.append(m.group(1))
        return f"\x00{len(stash) - 1}\x00"

    out = CODE_SPAN.sub(park, out)
    for pat, rep in INLINE:
        out = pat.sub(rep, out)
    for i, code in enumerate(stash):
        out = out.replace(f"\x00{i}\x00", f"<code>{code}</code>")
    return out


def md_to_html(md: str) -> str:
    """Deliberately small. Handles what the brief actually uses and nothing else."""
    lines, body, list_stack = md.splitlines(), [], []

    def close_lists(to: int = 0) -> None:
        while len(list_stack) > to:
            body.append(f"</{list_stack.pop()}>")

    para: list[str] = []

    def flush_para() -> None:
        if para:
            body.append(f"<p>{inline(' '.join(para))}</p>")
            para.clear()

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()

        if not stripped:
            flush_para(); close_lists(); continue
        if re.fullmatch(r"-{3,}|_{3,}|\*{3,}", stripped):
            flush_para(); close_lists(); body.append("<hr>"); continue

        m = re.match(r"(#{1,6})\s+(.*)", stripped)
        if m:
            flush_para(); close_lists()
            lvl = min(len(m.group(1)) + 1, 6)   # h1 in the doc becomes h2 on the page
            body.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>")
            continue

        m = re.match(r"[-*+]\s+\[[ xX]\]\s+(.*)|[-*+]\s+(.*)", stripped)
        if m:
            flush_para()
            if not list_stack:
                list_stack.append("ul"); body.append("<ul>")
            body.append(f"<li>{inline(m.group(1) or m.group(2))}</li>")
            continue

        m = re.match(r"\d+[.)]\s+(.*)", stripped)
        if m:
            flush_para()
            if not list_stack:
                list_stack.append("ol"); body.append("<ol>")
            body.append(f"<li>{inline(m.group(1))}</li>")
            continue

        para.append(stripped)

    flush_para(); close_lists()
    return "\n".join(body)


# --------------------------------------------------------------- brief summarising
# Match BOTH the typed v3 headings (SOLVE / ASK / HUMAN) and the older v2 ones
# (🤖 draft / 🟡 decision / 🧠 your turn), because a plan file written by either
# format must summarise correctly. Getting this wrong is not cosmetic: the first
# v3 brief reported "0 decisions" while carrying 3 ASKs, which is exactly the
# number a person would act on.
SECTIONS = [
    ("drafts", re.compile(r"^##\s*🤖")),
    ("asks", re.compile(r"^##\s*(❓|🟡)")),
    ("your_turn", re.compile(r"^##\s*🧠")),
]
# Headings that end a counted section without starting a new one.
STOP = re.compile(r"^##\s*(🗑️|✅|Findings|Honesty|Run economics)")


def summarise(md: str) -> dict:
    """Counts per bucket + the single most important line, for the notification."""
    counts = {k: 0 for k, _ in SECTIONS}
    current = None
    top = None

    for raw in md.splitlines():
        line = raw.strip()
        matched = False
        for key, pat in SECTIONS:
            if pat.match(line):
                current, matched = key, True
                break
        if matched:
            continue
        if line.startswith("##"):
            current = None
            continue
        # Count only TOP-LEVEL bullets. Indented sub-bullets are elaboration on the
        # item above them, not separate items, and counting them inflated every
        # number in the notification (9/21/13 where the truth was 2/8/12).
        indent = len(raw) - len(raw.lstrip())
        if current and indent <= 1 and re.match(r"^[-*]\s+(\[[ xX]\]\s*)?\S", line):
            counts[current] += 1
            if current in ("asks", "decisions") and top is None:
                top = strip_md(line)

    if top is None:                      # fall back to the first bold statement
        m = re.search(r"^\s*[-*]?\s*\*\*(.+?)\*\*", md, re.M)
        top = strip_md(m.group(1)) if m else "See the brief."
    return {"counts": counts, "top": top}


def strip_md(text: str) -> str:
    text = re.sub(r"^[-*]\s+(\[[ xX]\]\s*)?", "", text.strip())
    text = re.sub(r"\*\*|\*|`", "", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def clip(s: str, n: int) -> str:
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


# --------------------------------------------------------------- channels
def render_html(md: str, date: str, bid: int | None) -> pathlib.Path:
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    out = RENDER_DIR / f"brief-{date}.html"
    # The reference is the whole point of the page's header: it is the handle you
    # paste into a terminal to carry this brief into a conversation. So it is the
    # first thing on the page, big, monospace, and one click to copy.
    ref = (f'''<div class="ref">
  <div class="ref-label">paste into your terminal to pick this up with Claude</div>
  <div class="ref-row">
    <code id="ref" class="ref-code">morning loop #{bid}</code>
    <button id="copy" onclick="copyRef()">Copy</button>
  </div>
</div>
<script>
function copyRef() {{
  var t = document.getElementById('ref').textContent;
  var done = function () {{
    var b = document.getElementById('copy');
    b.textContent = 'Copied'; b.classList.add('ok');
    setTimeout(function () {{ b.textContent = 'Copy'; b.classList.remove('ok'); }}, 1600);
  }};
  // navigator.clipboard needs a secure context and this page is opened over
  // file://, so the execCommand path is the one that usually runs. Keep both.
  if (navigator.clipboard && window.isSecureContext) {{
    navigator.clipboard.writeText(t).then(done, fallback);
  }} else {{ fallback(); }}
  function fallback() {{
    var a = document.createElement('textarea');
    a.value = t; a.style.position = 'fixed'; a.style.opacity = '0';
    document.body.appendChild(a); a.select();
    try {{ document.execCommand('copy'); done(); }}
    catch (e) {{ window.getSelection().selectAllChildren(document.getElementById('ref')); }}
    document.body.removeChild(a);
  }}
}}
</script>''' if bid else "")
    out.write_text(
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<title>Morning Brief #{bid or ''} {date}</title>"
        "<style>body{font-family:-apple-system,Segoe UI,sans-serif;line-height:1.55;"
        "max-width:50em;margin:2rem auto 3rem;padding:0 1.2rem;color:#1a1a1a}"
        "code{background:#f4f4f5;padding:.1em .3em;border-radius:3px;font-size:.9em}"
        "h2{margin-top:2rem;border-bottom:1px solid #e5e5e5;padding-bottom:.3rem}"
        "li{margin:.35rem 0}hr{border:0;border-top:1px solid #e5e5e5;margin:2rem 0}"
        # the reference block: the handle for carrying this brief into a terminal
        ".ref{border:2px solid #2563eb;border-radius:10px;padding:.9rem 1.1rem;"
        "margin:0 0 2rem;background:#eff6ff}"
        ".ref-label{font-size:.75rem;letter-spacing:.06em;text-transform:uppercase;"
        "color:#2563eb;font-weight:600;margin-bottom:.5rem}"
        ".ref-row{display:flex;align-items:center;gap:.75rem;flex-wrap:wrap}"
        ".ref-code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;"
        "font-size:1.5rem;font-weight:700;background:transparent;padding:0;"
        "color:#1e40af;user-select:all}"
        ".ref button{font:inherit;font-size:.85rem;padding:.35rem .9rem;cursor:pointer;"
        "border:1px solid #2563eb;border-radius:6px;background:#fff;color:#2563eb;"
        "font-weight:600;margin-left:auto}"
        ".ref button:hover{background:#2563eb;color:#fff}"
        ".ref button.ok{background:#16a34a;border-color:#16a34a;color:#fff}"
        "@media(prefers-color-scheme:dark){body{background:#1a1a1a;color:#e8e8e8}"
        "code{background:#2d2d30}h2{border-color:#333}hr{border-color:#333}"
        ".ref{background:#11213d;border-color:#3b82f6}"
        ".ref-label{color:#7dabff}.ref-code{color:#bfdbfe}"
        ".ref button{background:transparent;border-color:#3b82f6;color:#7dabff}"
        ".ref button:hover{background:#3b82f6;color:#fff}}"
        "</style></head><body>" + ref + md_to_html(md) + "</body></html>"
    )
    return out


def notify_macos(summary: dict, html: pathlib.Path, bid: int | None,
                 open_brief: bool, dry: bool) -> None:
    c = summary["counts"]
    title = f"☀️ Morning Brief #{bid}" if bid else "☀️ Morning Brief"
    subtitle = f"{c['drafts']} to draft · {c['asks']} asks · {c['your_turn']} your turn"
    body = clip(summary["top"], 180)

    def osa(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"')

    script = (f'display notification "{osa(body)}" '
              f'with title "{osa(title)}" subtitle "{osa(subtitle)}" sound name "Glass"')
    if dry:
        print(f"[dry-run] osascript: {script}")
        print(f"[dry-run] would open: {html}")
        return
    try:
        subprocess.run(["osascript", "-e", script], check=True,
                       capture_output=True, text=True, timeout=20)
    except subprocess.CalledProcessError as e:
        die(3, f"osascript failed: {e.stderr.strip() or e}")
    except (OSError, subprocess.SubprocessError) as e:
        die(3, f"could not send the macOS notification: {e}")
    if open_brief:
        # -g opens without stealing focus, so a 07:52 run does not hijack the screen
        subprocess.run(["open", "-g", str(html)], capture_output=True, timeout=20)


def notify_mattermost(summary: dict, md: str, bid: int | None,
                      webhook: str, dry: bool) -> None:
    c = summary["counts"]
    head = (f"### ☀️ Morning Brief {'#' + str(bid) if bid else ''}\n"
            f"**{c['drafts']}** to draft · **{c['asks']}** asks · "
            f"**{c['your_turn']}** your turn\n\n"
            f"**Top of your list:** {summary['top']}\n\n---\n")
    # Mattermost rejects very long posts; keep the head guaranteed and clip the body.
    body = md if len(md) < 14000 else md[:14000] + "\n\n_(truncated, full brief in the repo)_"
    payload = json.dumps({"text": head + body}).encode()

    if dry:
        print(f"[dry-run] POST {webhook[:40]}... ({len(payload)} bytes)")
        return
    req = urllib.request.Request(webhook, data=payload,
                                headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            if r.status != 200:
                die(3, f"webhook returned HTTP {r.status}")
    except urllib.error.HTTPError as e:
        die(3, f"webhook rejected the post: HTTP {e.code} {e.read()[:200]!r}")
    except (urllib.error.URLError, OSError) as e:
        die(3, f"could not reach the Mattermost webhook: {e}")


# --------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--brief", required=True)
    ap.add_argument("--channel", default=os.environ.get("MORNING_NOTIFY_CHANNEL", "macos"),
                    choices=["macos", "mattermost", "file"])
    ap.add_argument("--date")
    ap.add_argument("--webhook", default=os.environ.get("MORNING_MATTERMOST_WEBHOOK"))
    ap.add_argument("--no-open", action="store_true", help="don't open the rendered brief")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    path = pathlib.Path(a.brief)
    if not path.is_absolute():
        path = REPO / path
    if not path.exists():
        die(2, f"brief file not found: {path}")
    md = path.read_text()
    if not md.strip():
        die(2, f"brief file is empty: {path}")

    date = a.date or dt.date.today().isoformat()
    bid = assign_id(load_index(), date, str(path), f"Morning Brief {date}")
    summary = summarise(md)
    html = render_html(md, date, bid)

    receipt = {
        "date": date, "brief_id": bid, "channel": a.channel,
        "brief_file": str(path), "rendered": str(html),
        "subject": f"☀️ Morning Brief #{bid} · {date}",
        "counts": summary["counts"], "top": summary["top"],
        "sent_at": None, "message_id": None,
    }

    if a.channel == "macos":
        notify_macos(summary, html, bid, not a.no_open, a.dry_run)
    elif a.channel == "mattermost":
        if not a.webhook:
            die(2, "no webhook. Pass --webhook or set MORNING_MATTERMOST_WEBHOOK.", receipt)
        notify_mattermost(summary, md, bid, a.webhook, a.dry_run)

    status = "dry_run" if a.dry_run else "sent"
    write_receipt(receipt | {
        "status": status,
        "sent_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    })
    print(f"notify: brief #{bid} for {date} delivered via {a.channel} "
          f"({summary['counts']['drafts']} to draft, {summary['counts']['asks']} asks, "
          f"{summary['counts']['your_turn']} your turn)")
    print(f"        rendered: {html}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
