#!/usr/bin/env python3
"""setup_workspace.py: give the loop the folder layout it actually runs in. Mac, Linux and Windows.

Why this script exists
---------------------
/morning and the scheduled runners read and write fixed workspace paths:
    05-automation/agent-manager/scripts/*.py      the trust, asks, tickets, notify scripts
    01-sprint-operations/current/                 the brief, drafts and questions
    06-skills/skills/agent-manager-config.<you>.yml
A standalone clone of this package has none of them, so a fresh clone installed
cleanly, passed the doctor, and then could not find its own scripts on the first
run. Found by the v4 fresh-install test, 2026-10-05.

This creates that layout inside the folder you work from (an existing workspace or
a brand-new one) and LINKS the package into it, so `git pull` in the package updates
the workspace. Where links are not allowed (Windows without Developer Mode) it copies
instead and says so: after each `git pull`, run `python scripts/upgrade.py` to bring
the copies up to date. It never overwrites a file of yours: anything already there
is left alone and reported.

Usage:
    python3 scripts/setup_workspace.py <workspace-dir> [your-name] [--dry-run] [--copy]
(scripts/setup-workspace.sh is the same thing, kept for the docs that name it.)
"""
from __future__ import annotations

import argparse
import datetime as dt
import getpass
import os
import pathlib
import shutil
import sys

PKG = pathlib.Path(__file__).resolve().parent.parent

FOLDERS = ("01-sprint-operations/current/agent-drafts", "05-automation/agent-manager/delivery-receipts",
           "05-automation/agent-manager/coach", "06-skills/skills", "10-meeting-notes")
LINKS = (("05-automation/agent-manager/scripts", "scripts"),
         ("05-automation/agent-manager/roles", "roles"),
         ("05-automation/agent-manager/morning-loop-share", "."),
         ("05-automation/agent-manager/rubrics", "rubrics"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("workspace")
    ap.add_argument("name", nargs="?", default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--copy", action="store_true", help="copy the package in instead of linking it")
    ap.add_argument("--role", help="a preset from roles/ (see roles/README.md): shapes the starter config")
    a = ap.parse_args()

    who = (a.name or os.environ.get("USER") or os.environ.get("USERNAME") or getpass.getuser() or "me").lower()
    ws = pathlib.Path(a.workspace).expanduser()
    if not a.dry_run:
        ws.mkdir(parents=True, exist_ok=True)
    ws = ws.resolve()
    dry = a.dry_run

    def say(msg: str) -> None:
        print(f"  {msg}")

    print("morning loop · workspace setup")
    say(f"package:   {PKG}")
    say(f"workspace: {ws}")
    if a.role and not (PKG / "roles" / f"{a.role}.yml").is_file():
        print(f"✗ no preset named {a.role}. Choose one of: "
              + ", ".join(sorted(p.stem for p in (PKG / "roles").glob("*.yml"))))
        return 2
    if ws == PKG:
        print("✗ the workspace cannot be the package clone itself. Pick another folder.")
        return 2

    print("\nfolders")
    for d in FOLDERS:
        if (ws / d).is_dir():
            say(f"= {d}")
        else:
            if not dry:
                (ws / d).mkdir(parents=True, exist_ok=True)
            say(f"+ {d}")

    print("\nthe package, inside your workspace")
    copied = []
    for at_rel, to_rel in LINKS:
        at, to = ws / at_rel, (PKG / to_rel).resolve()
        if at.is_symlink():
            say(f"= {at_rel}" if at.resolve() == to else f"! {at_rel} links somewhere else ({at.resolve()}); left alone")
            continue
        if at.exists():
            say(f"! {at_rel} already exists and is not a link; left alone. "
                f"`python3 scripts/upgrade.py --workspace {ws}` keeps its contents current")
            continue
        if to_rel == "." and (a.copy or not can_link(ws)):
            say(f"· {at_rel}: skipped in copy mode (it is only a pointer back to the package)")
            continue
        if not a.copy and not dry and try_link(at, to):
            say(f"+ {at_rel} -> {to_rel}")
            continue
        if not dry:
            shutil.copytree(to, at, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        copied.append(at_rel)
        say(f"+ {at_rel} (copied{'' if a.copy else ': this system does not allow links'})")

    print("\nstarter files (only where none exists)")
    starters = ((f"06-skills/skills/agent-manager-config.{who}.yml", "agent-manager-config.template.yml"),
                ("05-automation/agent-manager/coach/plan.md", "coach/plan.template.md"),
                ("01-sprint-operations/current/commitments-ledger.md", "templates/commitments-ledger.template.md"))
    for at_rel, src_rel in starters:
        at = ws / at_rel
        if at.exists():
            say(f"= {at_rel} (yours, untouched)")
            continue
        if not dry:
            text = (PKG / src_rel).read_text(encoding="utf-8")
            # The reconciler refuses a ledger with no date marker, so stamp today on a fresh one.
            text = text.replace("`last_reconciled: never`", f"`last_reconciled: {dt.date.today().isoformat()}`")
            if src_rel == "agent-manager-config.template.yml" and a.role:
                text = apply_role(text, a.role)
            at.write_text(text, encoding="utf-8")
        say(f"+ {at_rel}")
    log = ws / "05-automation/agent-manager/run-log.md"
    if not log.exists():
        if not dry:
            log.touch()
        say("+ 05-automation/agent-manager/run-log.md")

    cfg = ws / f"06-skills/skills/agent-manager-config.{who}.yml"
    win = os.name == "nt"
    print("\nnext")
    say(f"1. Fill {cfg.relative_to(ws)} (owner, timezone, routing). /jtbd-capture helps.")
    say(f"2. Set MORNING_CONFIG to {cfg}")
    say("   " + (f'setx MORNING_CONFIG "{cfg}"' if win else f'export MORNING_CONFIG="{cfg}"   (add it to your shell profile)'))
    say(f"3. cd \"{ws}\" and run: python3 05-automation/agent-manager/scripts/doctor.py")
    say("4. Run /morning once by hand from the workspace, then schedule it: scripts/SETUP-DELIVERY.md")
    if copied:
        say(f"Copied, not linked: {', '.join(copied)}. After each `git pull` of the package, run")
        say(f"   python3 \"{PKG / 'scripts' / 'upgrade.py'}\" --workspace \"{ws}\" --apply")
    if dry:
        print("\nDry run finished. Nothing was written.")
    return 0


def apply_role(text: str, role: str) -> str:
    """Starter config shaped by a role preset: role_profile set, routing replaced by
    the preset's rules (all of which ship), and the preset's gaps listed as comments
    so the config never claims coverage it does not have. Plain text edits on the
    template, so no YAML library is needed and every comment in it survives."""
    import re
    preset = (PKG / "roles" / f"{role}.yml").read_text(encoding="utf-8")
    text = re.sub(r"^(  role_profile:).*$", rf"\1 {role}   # roles/{role}.yml", text, count=1, flags=re.M)
    m = re.search(r"^title:\s*(.+)$", preset, re.M)
    if m:
        text = re.sub(r"^(  role:) <[^>]*>.*$", rf"\1 {m.group(1).strip()}   # FILL: your exact title", text, count=1, flags=re.M)
    rules = re.findall(r"^  - \{(.+)\}\s*$", preset[preset.index("\nrouting:"):preset.index("\ngaps:")], re.M)
    gaps = re.findall(r'^  - "(.+)"\s*$', preset[preset.index("\ngaps:"):], re.M)
    out = [f"routing:   # from roles/{role}.yml. Yours to change: /jtbd-capture tunes it to your real jobs"]
    for r in rules:
        fields = [f.strip() for f in r.split(", ")]
        out.append("  - " + fields[0])
        out += ["    " + f for f in fields[1:]]
        out.append("")
    if gaps:
        out.append("  # GAPS for this role: jobs no shipped skill drafts yet. Commented on purpose.")
        out += [f"  # - {g}" for g in gaps]
    start = text.index("\nrouting:\n") + 1
    end = text.index("\n# ----", start)
    return text[:start] + "\n".join(out).rstrip() + "\n" + text[end:]


def can_link(ws: pathlib.Path) -> bool:
    if os.environ.get("MORNING_NO_SYMLINK"):
        return False
    probe = ws / ".morning-loop-link-probe"
    try:
        probe.symlink_to(PKG, target_is_directory=True)
        probe.unlink()
        return True
    except (OSError, NotImplementedError):
        return False


def try_link(at: pathlib.Path, to: pathlib.Path) -> bool:
    if os.environ.get("MORNING_NO_SYMLINK"):
        return False
    try:
        at.parent.mkdir(parents=True, exist_ok=True)
        at.symlink_to(to, target_is_directory=to.is_dir())
        return True
    except (OSError, NotImplementedError):
        return False


if __name__ == "__main__":
    sys.exit(main())
