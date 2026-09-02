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

This is that catch. It distinguishes four states that currently look identical:

    ok            the skill resolves from a real load path
    NOT INSTALLED it ships in this package, but was never installed
    NOT LOADABLE  the file exists, in a folder skills cannot load from
    MISSING       no file anywhere, so the rule can never run

Run it after setup, and again whenever you edit your config:

    python3 scripts/doctor.py                    # auto-resolve config and root
    python3 scripts/doctor.py --config path      # or point at one
    python3 scripts/doctor.py --repo-root path   # or state the root outright
    python3 scripts/doctor.py --client=opencode  # check another client's paths
    python3 scripts/doctor.py --json             # machine-readable, for the loop

Exit codes: 0 all good · 1 at least one rule cannot run · 2 no config found.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys

# Each client loads skills from its own directory, and a skill installed for the
# wrong client is invisible in exactly the way this script exists to catch: the
# file is on disk, the config names it, and it can never resolve. So the client
# is part of the diagnosis, not an assumption.
#
# OpenCode has no separate commands directory -- a skill IS the slash command --
# so /morning resolves from the same place as every drafter.
# OpenCode has no separate commands directory -- a skill IS the slash command --
# so /morning resolves from the same place as every drafter. It takes the skill's
# identity from the directory name, so `name:` in the frontmatter is conventional
# rather than required, and doctor does not fail a skill for omitting it: a check
# that reports a working skill as broken costs more than the one it catches.
CLIENTS = {
    "claude": {
        "skills": ("{repo}/.claude/skills/{name}/SKILL.md",
                   "{home}/.claude/skills/{name}/SKILL.md"),
        "commands": ("{repo}/.claude/commands/{name}.md",
                     "{home}/.claude/commands/{name}.md"),
    },
    "opencode": {
        "skills": ("{repo}/.opencode/skills/{name}/SKILL.md",
                   "{home}/.config/opencode/skills/{name}/SKILL.md"),
        "commands": ("{repo}/.opencode/skills/{name}/SKILL.md",
                     "{home}/.config/opencode/skills/{name}/SKILL.md"),
    },
}

# Places a skill is commonly found but can NEVER load from. Listing them is the
# whole point: "missing" and "in the wrong folder" need different fixes.
DECOY_PATHS = ("{repo}/06-skills/skills/{name}.md",
               "{repo}/05-automation/agent-manager/morning-loop-share/skills/{name}.md",
               "{repo}/skills/{name}.md",
               "{repo}/.claude/skills/{name}.md")          # flat file, no directory

# The package's own skills/ directory. A skill sitting here has shipped and simply
# has not been installed yet, which needs the installer rather than someone writing
# the skill from scratch. Same distinction the commands check already makes, and
# reserving MISSING for names that exist nowhere is the point: "write the skill"
# and "run the installer" are not the same instruction, and the wrong one costs an
# afternoon of hunting for files that were in the package all along.
SHIPPED_PATHS = ("{pkg}/skills/{name}/SKILL.md",
                 "{repo}/skills/{name}/SKILL.md",
                 "{repo}/05-automation/agent-manager/morning-loop-share/skills/{name}/SKILL.md")

# A routing rule may name a command rather than a skill: the daily spine reuses
# team-standup. Those ship in commands/ and the installer places them per client,
# so the shipped-not-installed state has to cover them too or the one name that
# only ever ships as a command reads as MISSING.
SHIPPED_COMMAND_PATHS = ("{pkg}/commands/{name}.md",
                         "{repo}/commands/{name}.md",
                         "{repo}/05-automation/agent-manager/morning-loop-share/commands/{name}.md")

CONFIG_CANDIDATES = (
    "{env}",
    # workspace layout
    "{repo}/06-skills/skills/agent-manager-config.{user}.yml",
    "{repo}/06-skills/skills/agent-manager-config.yml",
    # standalone package clone: the config sits next to the docs
    "{repo}/agent-manager-config.{user}.yml",
    "{repo}/agent-manager-config.yml",
)


def looks_like_package(p: pathlib.Path) -> bool:
    """Is this the package clone itself? It ships commands/, skills/ and this script."""
    return ((p / "commands").is_dir() and (p / "skills").is_dir()
            and (p / "scripts" / "doctor.py").is_file())


def looks_like_workspace(p: pathlib.Path) -> bool:
    """Is this a workspace that CLONES the package, rather than the clone itself?

    Home and the filesystem root are deliberately excluded. ~/.claude is the
    user-level load path, not a workspace root, and treating it as one would send
    config resolution to the home directory instead of to the clone.
    """
    if p == pathlib.Path.home() or p == p.parent:
        return False
    return ((p / "06-skills").is_dir() or (p / "05-automation").is_dir()
            or (p / ".claude").is_dir())


def repo_root(start: pathlib.Path) -> tuple[pathlib.Path, str]:
    """Resolve the root that load paths and config candidates hang off.

    The git root is the right answer for a standalone clone. It is the WRONG
    answer when the package is cloned INSIDE a workspace, which is the layout
    ADOPT-MORNING.md blesses: then the git root is the package, and
    <package>/.claude/skills is a folder nothing loads from. A fully installed
    setup came back as "4 thing(s) cannot run", and the fix text told the adopter
    to write skills that already ship and to comment out working coverage.

    So probe the layout instead of counting parents. Counting parents against a
    layout it did not expect is what produced this class of bug twice already.

    Returns the root and how it was chosen, because a silently wrong root reports
    every name under it as MISSING and that is exactly what this tool exists to
    catch. The caller prints the reason next to the config line.
    """
    git_root = next((p for p in [start, *start.parents] if (p / ".git").exists()), None)
    root = git_root or (start.parent if looks_like_package(start.parent) else start)
    if not looks_like_package(root):
        return root, "git root" if git_root else "no git root, using the script's directory"
    ws = next((p for p in root.parents if looks_like_workspace(p)), None)
    if ws:
        return ws, "workspace holding the package clone"
    return root, "standalone package clone"


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


def detect_client(explicit: str | None) -> str:
    if explicit:
        if explicit not in CLIENTS:
            print(f"✗ unknown client: {explicit} (expected {' or '.join(CLIENTS)})")
            raise SystemExit(2)
        return explicit
    env = os.environ.get("MORNING_CLIENT")
    if env in CLIENTS:
        return env
    home = pathlib.Path.home()
    if (home / ".claude/skills").is_dir():
        return "claude"
    if (home / ".config/opencode").is_dir():
        return "opencode"
    return "claude"


def resolve_skill(name: str, repo: pathlib.Path, home: pathlib.Path,
                  pkg: pathlib.Path, client: str = "claude") -> dict:
    spec = CLIENTS[client]
    for tpl in spec["skills"]:
        p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
        if p.is_file():
            return {"state": "ok", "at": str(p)}
    # A routing rule may legitimately name a COMMAND rather than a skill: the
    # daily spine reuses /standup. Those resolve from a different directory, and
    # reporting them as MISSING was doctor's own first false positive.
    for tpl in spec["commands"]:
        p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
        if p.is_file():
            return {"state": "ok (command)", "at": str(p)}
    # Installed, but for a client you are not running. Same file, same name, and
    # it can never resolve -- which is the wrong-folder case across clients.
    for other, ospec in CLIENTS.items():
        if other == client:
            continue
        for tpl in ospec["skills"]:
            p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
            if p.is_file():
                return {"state": "NOT LOADABLE", "at": str(p),
                        "fix": f"installed for {other}, but you are running {client}. "
                               f"Re-run ./scripts/install-skills.sh --client={client}"}
    # Shipped in the package, never installed. Client-independent on purpose: the
    # package's skills/ directory is the same file for every client, and the fix
    # is the installer pointed at the client you actually run.
    for tpl in (*SHIPPED_PATHS, *SHIPPED_COMMAND_PATHS):
        p = pathlib.Path(tpl.format(repo=repo, home=home, pkg=pkg, name=name))
        if p.is_file():
            return {"state": "NOT INSTALLED", "at": str(p),
                    "fix": f"ships in this package, not installed yet. Run "
                           f"./scripts/install-skills.sh --client={client} "
                           f"(it installs commands too)"}
    for tpl in DECOY_PATHS:
        p = pathlib.Path(tpl.format(repo=repo, home=home, name=name))
        if p.is_file():
            target = pathlib.Path(spec["skills"][1].format(repo=repo, home=home, name=name))
            return {"state": "NOT LOADABLE", "at": str(p),
                    "fix": f"mkdir -p {target.parent} && cp '{p}' {target}"}
    return {"state": "MISSING", "at": None,
            "fix": f"no file named {name} anywhere, not even in this package. Either "
                   f"write the skill, or comment the rule out so it stops looking "
                   f"like coverage."}


def check_frontmatter(path: str, client: str = "claude") -> str | None:
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
    # --repo is the older spelling, kept so existing invocations do not break.
    ap.add_argument("--repo-root", "--repo", dest="repo_root",
                    help="state the root that load paths hang off (default: probe)")
    ap.add_argument("--client", choices=sorted(CLIENTS),
                    help="which client's load paths to check (default: detect)")
    args = ap.parse_args()

    here = pathlib.Path(__file__).resolve().parent
    pkg = here.parent
    if args.repo_root:
        repo, root_why = pathlib.Path(args.repo_root).expanduser(), "given with --repo-root"
    else:
        repo, root_why = repo_root(here)
    home = pathlib.Path.home()
    client = detect_client(args.client)

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
            r = resolve_skill(name, repo, home, pkg, client)
            if r["state"] == "ok":
                fm = check_frontmatter(r["at"], client)
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
        installed = [str(p) for p in
                     (pathlib.Path(tpl.format(repo=repo, home=home, name=cmd))
                      for tpl in CLIENTS[client]["commands"]) if p.is_file()]
        if installed:
            cmd_states.append({"command": f"/{cmd}", "state": "ok", "at": installed[0]})
            continue
        # Same three-state distinction as skills: shipped-but-not-installed needs a
        # different fix from missing-entirely, and conflating them is what sent people
        # hunting for files that were sitting in the package all along.
        # pkg is listed because the root may be the workspace ABOVE the clone, and
        # then repo/commands does not exist while the package still ships the file.
        shipped = [str(p) for p in (pkg / "commands" / f"{cmd}.md",
                                    repo / "commands" / f"{cmd}.md",
                                    repo / "05-automation/agent-manager/morning-loop-share/commands" / f"{cmd}.md")
                   if p.is_file()]
        if shipped:
            cmd_states.append({"command": f"/{cmd}", "state": "NOT INSTALLED", "at": shipped[0],
                               "fix": f"run ./scripts/install-skills.sh --client={client} "
                                      f"(it installs commands too)"})
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

    # Rubrics. morning.md's verify stage resolves {paths.rubrics_dir}/{skill}.rubric.yml
    # and falls back to _base alone when a skill has no rubric of its own. So a
    # missing skill rubric is a real gap and a warning, while a missing rubrics_dir
    # key is a failure: without it nothing resolves at all, not even the fallback.
    # This is the one place the config-to-package mismatch class lives, and until
    # now doctor never looked at it.
    rubrics_state: list[dict] = []
    rubrics_dir_raw = (cfg.get("paths") or {}).get("rubrics_dir")
    shipped_rubrics = pkg / "rubrics"
    try:
        hint = f"{shipped_rubrics.relative_to(repo)}/"
    except ValueError:
        hint = f"{shipped_rubrics}/"
    if not rubrics_dir_raw:
        rubrics_state.append({"what": "paths.rubrics_dir", "state": "MISSING", "at": None,
                              "fix": "your config defines no paths.rubrics_dir, so the verify "
                                     "stage cannot resolve any rubric, including the _base "
                                     f'fallback. Add  rubrics_dir: "{hint}"  under paths: '
                                     "(this package ships the rubrics there)."})
        blocked += 1
    else:
        rdir = pathlib.Path(rubrics_dir_raw).expanduser()
        if not rdir.is_absolute():
            rdir = repo / rubrics_dir_raw
        base = rdir / "_base.rubric.yml"
        if base.is_file():
            rubrics_state.append({"what": "_base.rubric.yml", "state": "ok", "at": str(base)})
        else:
            fix = (f"rubrics_dir points at {rdir}, which holds no _base.rubric.yml. "
                   "Every rubric extends it and the fallback IS it, so no draft can "
                   "be graded.")
            if (shipped_rubrics / "_base.rubric.yml").is_file():
                fix += (f' This package ships them at {shipped_rubrics}, so from this '
                        f'root the value wants to be  rubrics_dir: "{hint}"  instead.')
            rubrics_state.append({"what": "_base.rubric.yml", "state": "MISSING",
                                  "at": str(base), "fix": fix})
            blocked += 1
        seen: list[str] = []
        for r in results:
            name = r.get("skill")
            if not name or name in seen:
                continue
            seen.append(name)
            rf = rdir / f"{name}.rubric.yml"
            rubrics_state.append({"what": name, "at": str(rf) if rf.is_file() else None,
                                  "state": "ok" if rf.is_file()
                                  else "_base fallback (no skill rubric)"})

    if args.json:
        print(json.dumps({"config": str(cfg_path), "client": client,
                          "root": str(repo), "root_from": root_why,
                          "parsed_by": cfg.get("_parsed_by", "yaml"),
                          "rules": results, "commands": cmd_states, "paths": paths_state,
                          "rubrics": rubrics_state, "blocked": blocked}, indent=2))
        return 1 if blocked else 0

    # The root is printed next to the config because a silently wrong root is the
    # class of bug this tool exists to catch, and it reports every name under it
    # as MISSING while looking perfectly healthy about it.
    print(f"\nMORNING LOOP DOCTOR\nclient: {client}\nconfig: {cfg_path}"
          f"\nroot:   {repo}  ({root_why})")
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

    print("\nRUBRICS")
    for r in rubrics_state:
        mark = "✓" if r["state"] == "ok" else ("!" if r["state"].startswith("_base") else "✗")
        print(f"  {mark} {r['what']:<24} {r['state']}")
        if r.get("fix"):
            print(f"      fix: {r['fix']}")

    print("\nPATHS")
    for p in paths_state:
        print(f"  {'✓' if p['state'] == 'ok' else '·'} {p['what']:<20} {p['state']}")

    print("\nMCPs — doctor cannot probe these; the loop's Phase 0 does it live.")
    print("  Expected by this config: Atlassian (required), Amplitude, Microsoft 365,")
    print("  and whatever `meeting_source` names. A missing MCP narrows the run; it")
    print("  does not break it. A missing SKILL silently does nothing, which is worse.")

    if blocked:
        # Only say what actually applies. The old text told you to comment the rule
        # out no matter what was blocked, which is wrong advice for a missing config
        # key: there is no rule to comment out, and following it removes coverage
        # that was never the problem.
        every = [*results, *cmd_states]
        broken_rules = [r for r in every if not str(r["state"]).startswith(("ok", "inline"))]
        advice: list[str] = []
        if broken_rules:
            advice.append("  A broken rule fires, finds nothing, and reports no error. Fix it or\n"
                          "  comment it out, so your config stops describing coverage you do not have.")
        if any(r["state"] == "NOT INSTALLED" for r in broken_rules):
            advice.append("  NOT INSTALLED means the file ships in this package and the installer is\n"
                          "  the whole fix. Do not write it again from scratch.")
        if not notifier:
            advice.append("  notify.py is not in either layout, so a finished brief has nothing to\n"
                          "  deliver it. Pull the latest package.")
        if any(r["state"] == "MISSING" for r in rubrics_state):
            advice.append("  A rubrics failure is a config path, not a rule: commenting anything out\n"
                          "  will not help. Point paths.rubrics_dir at the shipped rubrics, or the\n"
                          "  verify stage cannot grade a single draft.")
        print(f"\n✗ {blocked} thing(s) cannot run, and each is silent at runtime.")
        print("\n".join(advice) + "\n")
    else:
        print("\n✓ Every rule resolves, both commands are present, rubrics are reachable.")
        print("  This does not mean the loop works, only that nothing is missing.")
        print("  The real test is one clean unattended scheduled run.\n")
    return 1 if blocked else 0


if __name__ == "__main__":
    sys.exit(main())
