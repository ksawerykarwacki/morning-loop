#!/usr/bin/env python3
"""
doctor.py — validate a morning-loop setup BEFORE you trust it.

Why this exists
---------------
Three developers independently reported that the loop's dev drafters "never ran".
The cause was not their config and not their role: skills load from exactly two
places, and the shared package shipped them somewhere else. A config can name a
skill that cannot possibly resolve, and nothing anywhere noticed.

Xitong described the symptom exactly: "it's easy to half-adopt. I had a working
config, drafts, and run-log, but /morning itself didn't work because the command
files were never copied. Nothing in the flow catches this."

This is that catch. It distinguishes three states that currently look identical:

    ok            the skill resolves from a real load path
    NOT LOADABLE  the file exists, in a folder skills cannot load from
    MISSING       no file anywhere, so the rule can never run

Run it after setup, and again whenever you edit your config:

    python3 scripts/doctor.py                 # auto-resolve the config
    python3 scripts/doctor.py --config path   # or point at one
    python3 scripts/doctor.py --json          # machine-readable, for the loop

Exit codes: 0 all good · 1 at least one rule cannot run · 2 no config found.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys

# Skills load from exactly these two shapes. Everything else is a doc shelf.
#   <repo>/.claude/skills/<name>/SKILL.md
#   ~/.claude/skills/<name>/SKILL.md
LOAD_PATHS = ("{repo}/.claude/skills/{name}/SKILL.md",
              "{home}/.claude/skills/{name}/SKILL.md")

# Places a skill is commonly found but can NEVER load from. Listing them is the
# whole point: "missing" and "in the wrong folder" need different fixes.
DECOY_PATHS = ("{repo}/06-skills/skills/{name}.md",
               "{repo}/05-automation/agent-manager/morning-loop-share/skills/{name}.md",
               "{repo}/skills/{name}.md",
               "{repo}/.claude/skills/{name}.md")          # flat file, no directory

CONFIG_CANDIDATES = (
    "{env}",
    # workspace layout
    "{repo}/06-skills/skills/agent-manager-config.{user}.yml",
    "{repo}/06-skills/skills/agent-manager-config.yml",
    # standalone package clone: the config sits next to the docs
    "{repo}/agent-manager-config.{user}.yml",
    "{repo}/agent-manager-config.yml",
)


def repo_root(start: pathlib.Path) -> pathlib.Path:
    """Walk up to the git root so the script works from anywhere in the repo."""
    for p in [start, *start.parents]:
        if (p / ".git").exists():
            return p
    return start


def find_config(repo: pathlib.Path, explicit: str | None) -> pathlib.Path | None:
    if explicit:
        p = pathlib.Path(explicit).expanduser()
        return p if p.is_file() else None
    user = (os.environ.get("USER") or "").lower()
    for tpl in CONFIG_CANDIDATES:
        raw = tpl.format(env=os.environ.get("MORNING_CONFIG", ""), repo=repo, user=user)
        if not raw:
            continue
        p = pathlib.Path(raw).expanduser()
        if p.is_file():
            return p
    return None


def parse_config(text: str) -> dict:
    """Extract what doctor needs without requiring PyYAML.

    Deliberately narrow: routing rule ids and their `skill:` values, plus the
    `paths:` block. If PyYAML is present we use it and this is skipped, because a
    real parser beats a regex every time it is available.
    """
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text) or {}
    except Exception:
        pass

    cfg: dict = {"routing": [], "paths": {}, "_parsed_by": "regex-fallback"}
    section = None
    rule: dict | None = None
    for raw in text.splitlines():
        if re.match(r"^[a-z_]+:", raw):
            if rule:
                cfg["routing"].append(rule)
                rule = None
            section = raw.split(":", 1)[0]
            continue
        if section == "routing":
            m = re.match(r"\s*-\s*id:\s*(\S+)", raw)
            if m:
                if rule:
                    cfg["routing"].append(rule)
                rule = {"id": m.group(1), "skill": None}
                continue
            if rule is not None:
                m = re.match(r"\s+skill:\s*(.+?)\s*(?:#.*)?$", raw)
                if m:
                    val = m.group(1).strip()
                    if val in ("null", "~", ""):
                        rule["skill"] = None
                    elif val.startswith("["):
                        rule["skill"] = [s.strip(" []'\"") for s in val.strip("[]").split(",") if s.strip()]
                    else:
                        rule["skill"] = val.strip("'\"")
        elif section == "paths":
            m = re.match(r"\s+([a-z_]+):\s*\"?([^\"#]+)\"?", raw)
            if m:
                cfg["paths"][m.group(1)] = m.group(2).strip()
    if rule:
        cfg["routing"].append(rule)
    return cfg


def resolve_skill(name: str, repo: pathlib.Path, home: pathlib.Path) -> dict:
    for tpl in LOAD_PATHS:
        p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
        if p.is_file():
            return {"state": "ok", "at": str(p)}
    # A routing rule may legitimately name a COMMAND rather than a skill: the
    # daily spine reuses /standup. Those resolve from a different directory, and
    # reporting them as MISSING was doctor's own first false positive.
    for base in (repo, home):
        p = base / ".claude/commands" / f"{name}.md"
        if p.is_file():
            return {"state": "ok (command)", "at": str(p)}
    for tpl in DECOY_PATHS:
        p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
        if p.is_file():
            return {"state": "NOT LOADABLE", "at": str(p),
                    "fix": f"mkdir -p ~/.claude/skills/{name} && "
                           f"cp '{p}' ~/.claude/skills/{name}/SKILL.md"}
    return {"state": "MISSING", "at": None,
            "fix": f"no file named {name} anywhere. Either write the skill, or "
                   f"comment the rule out so it stops looking like coverage."}


def check_frontmatter(path: str) -> str | None:
    """A SKILL.md without frontmatter loads as a file, not as a skill."""
    try:
        head = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")[:400]
    except OSError:
        return "unreadable"
    if not head.lstrip().startswith("---"):
        return "no frontmatter"
    if "description:" not in head:
        return "frontmatter has no description"
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate a morning-loop setup.")
    ap.add_argument("--config")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--repo")
    args = ap.parse_args()

    here = pathlib.Path(__file__).resolve().parent
    repo = pathlib.Path(args.repo).expanduser() if args.repo else repo_root(here)
    home = pathlib.Path.home()

    cfg_path = find_config(repo, args.config)
    if not cfg_path:
        print("✗ No config found. Tried $MORNING_CONFIG, "
              "06-skills/skills/agent-manager-config.<user>.yml, then "
              "agent-manager-config.yml.\n"
              "  Copy the template first: skills/agent-manager-config.template.yml")
        return 2

    cfg = parse_config(cfg_path.read_text(encoding="utf-8", errors="replace"))
    rules = cfg.get("routing") or []

    results, blocked = [], 0
    for rule in rules:
        skills = rule.get("skill")
        if skills is None:
            results.append({"rule": rule.get("id"), "skill": None, "state": "inline",
                            "note": "no skill: handled inside the command"})
            continue
        for name in (skills if isinstance(skills, list) else [skills]):
            r = resolve_skill(name, repo, home)
            if r["state"] == "ok":
                fm = check_frontmatter(r["at"])
                if fm:
                    r = {"state": "NOT LOADABLE", "at": r["at"],
                         "fix": f"{r['at']} has a problem: {fm}. A SKILL.md without "
                                f"frontmatter and a description does not register as a skill."}
            if not r["state"].startswith("ok"):
                blocked += 1
            results.append({"rule": rule.get("id"), "skill": name, **r})

    # The other half of Xitong's half-adopt: the command itself.
    cmd_states = []
    for cmd in ("morning", "standup"):
        installed = [str(p) for p in (repo / ".claude/commands" / f"{cmd}.md",
                                      home / ".claude/commands" / f"{cmd}.md") if p.is_file()]
        if installed:
            cmd_states.append({"command": f"/{cmd}", "state": "ok", "at": installed[0]})
            continue
        # Same three-state distinction as skills: shipped-but-not-installed needs a
        # different fix from missing-entirely, and conflating them is what sent people
        # hunting for files that were sitting in the package all along.
        shipped = [str(p) for p in (repo / "commands" / f"{cmd}.md",
                                    repo / "05-automation/agent-manager/morning-loop-share/commands" / f"{cmd}.md")
                   if p.is_file()]
        if shipped:
            cmd_states.append({"command": f"/{cmd}", "state": "NOT INSTALLED", "at": shipped[0],
                               "fix": "run ./scripts/install-skills.sh (it installs commands too)"})
        else:
            cmd_states.append({"command": f"/{cmd}", "state": "MISSING", "at": None,
                               "fix": "not in this package either. Pull the latest package."})
        blocked += 1

    # The notifier lives in a different place in the workspace layout and in a
    # standalone package clone. Reporting MISSING when it is sitting in scripts/
    # next to this file is the same false negative the commands check just had.
    notifier = next((c for c in (repo / "05-automation/agent-manager/scripts/notify.py",
                                 repo / "scripts/notify.py",
                                 here / "notify.py") if c.is_file()), None)
    paths_state = [{"what": "notifier", "state": "ok" if notifier else "MISSING",
                    "at": str(notifier) if notifier else "not found in either layout"}]
    if not notifier:
        blocked += 1
    for key in ("commitments_ledger", "run_log"):
        raw = (cfg.get("paths") or {}).get(key)
        if raw:
            p = repo / raw.replace("{DATE}", "")
            paths_state.append({"what": key, "state": "ok" if p.exists() else "missing (will be created)",
                                "at": str(p)})

    if args.json:
        print(json.dumps({"config": str(cfg_path), "parsed_by": cfg.get("_parsed_by", "yaml"),
                          "rules": results, "commands": cmd_states, "paths": paths_state,
                          "blocked": blocked}, indent=2))
        return 1 if blocked else 0

    print(f"\nMORNING LOOP DOCTOR\nconfig: {cfg_path}")
    if cfg.get("_parsed_by"):
        print("note:   PyYAML not installed, using the narrow fallback parser. "
              "Install PyYAML for a stricter read.")

    print("\nROUTING RULES")
    width = max([len(str(r.get("rule"))) for r in results] or [12])
    for r in results:
        mark = "✓" if r["state"].startswith("ok") else ("·" if r["state"] == "inline" else "✗")
        skill = r["skill"] or "(inline)"
        print(f"  {mark} {str(r['rule']).ljust(width)}  {skill:<24} {r['state']}")
        if r.get("fix"):
            print(f"      fix: {r['fix']}")

    print("\nCOMMANDS")
    for c in cmd_states:
        print(f"  {'✓' if c['state'] == 'ok' else '✗'} {c['command']:<10} {c['state']}"
              + (f"  {c['at']}" if c.get("at") else ""))
        if c.get("fix"):
            print(f"      fix: {c['fix']}")

    print("\nPATHS")
    for p in paths_state:
        print(f"  {'✓' if p['state'] == 'ok' else '·'} {p['what']:<20} {p['state']}")

    print("\nMCPs — doctor cannot probe these; the loop's Phase 0 does it live.")
    print("  Expected by this config: Atlassian (required), Amplitude, Microsoft 365,")
    print("  and whatever `meeting_source` names. A missing MCP narrows the run; it")
    print("  does not break it. A missing SKILL silently does nothing, which is worse.")

    if blocked:
        print(f"\n✗ {blocked} thing(s) cannot run. Every one is silent at runtime: the rule")
        print("  fires, finds nothing, and reports no error. Fix them or comment the rules")
        print("  out, so your config stops describing coverage you do not have.\n")
    else:
        print("\n✓ Every rule resolves and both commands are present.")
        print("  This does not mean the loop works, only that nothing is missing.")
        print("  The real test is one clean unattended scheduled run.\n")
    return 1 if blocked else 0


if __name__ == "__main__":
    sys.exit(main())
