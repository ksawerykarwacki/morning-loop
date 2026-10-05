#!/usr/bin/env python3
"""upgrade.py: move an existing morning-loop setup to this version without losing anyone's work.

Why this exists
---------------
Until v4 the installer handled a file that differed from the package by backing it
up and then overwriting it. For a skill someone had tuned to their role, that meant
the tuned version silently stopped loading and the stock one took its place: the
work was "saved" in a .before-v3.1 file nobody looks at. And a workspace whose
scripts were copied rather than linked got nothing from a new version at all.

The rule this script enforces
-----------------------------
A file is replaced only if it is a version this package once shipped. Git can answer
that exactly: hash the file with `git hash-object` and ask the package repo whether
it has ever held that blob. So:

    NEW     not on your machine yet               -> added
    SAME    already identical to this version     -> left alone
    STOCK   a version this package shipped before -> upgraded (after a backup)
    CUSTOM  differs from every shipped version    -> YOURS IS KEPT, the new version is
                                                     written beside it as <name>.v4-new
                                                     so you can merge what you want
    YOURS   yours, and the package has no such file -> never touched, only listed

Your config and your runner are never edited. For each, this writes a suggestion file
next to it (`*.v4-additions.yml`, `run-prep.v4.sh`) and the report says what it adds.

Every file that would change is copied to one backup folder first, with a manifest,
and `--restore <folder>` puts all of it back.

Usage (from anywhere; run it from your package clone):
    python3 scripts/upgrade.py --workspace ~/work/my-workspace            # dry run: the plan
    python3 scripts/upgrade.py --workspace ~/work/my-workspace --apply    # do it
    python3 scripts/upgrade.py --restore <backup folder>                  # undo it
Options: --client claude|opencode (default: detected), --repo-scope (skills in the
workspace's .claude/ instead of your home), --config <file> (default: $MORNING_CONFIG
or the one config in 06-skills/skills/).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

PKG = pathlib.Path(__file__).resolve().parent.parent
VERSION = "v4"


# --------------------------------------------------------------------------- git
def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(PKG), *args], capture_output=True, text=True)


HAVE_HISTORY = git("rev-parse", "--git-dir").returncode == 0


def blob(path: pathlib.Path) -> str | None:
    r = subprocess.run(["git", "hash-object", "--no-filters", str(path)], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


KNOWN = PKG / "scripts" / "known-shipped-blobs.txt"
KNOWN_BLOBS = ({ln.strip() for ln in KNOWN.read_text().splitlines() if ln.strip() and not ln.startswith("#")}
               if KNOWN.is_file() else set())


def shipped_before(path: pathlib.Path) -> bool:
    """True if this exact content was ever shipped: in this repo's history, or
    through the workspace share folder that distributed the loop before GitHub."""
    h = blob(path)
    if not h:
        return False
    if h in KNOWN_BLOBS:
        return True
    if not HAVE_HISTORY:
        return False          # no history to prove it was stock: treat it as yours
    return git("cat-file", "-e", h).returncode == 0


def same(a: pathlib.Path, b: pathlib.Path) -> bool:
    return a.read_bytes() == b.read_bytes()


# --------------------------------------------------------------------------- targets
def detect_client(explicit: str | None, home: pathlib.Path) -> str:
    if explicit:
        return explicit
    env = os.environ.get("MORNING_CLIENT")
    if env in ("claude", "opencode"):
        return env
    if (home / ".config" / "opencode").is_dir() and not (home / ".claude").is_dir():
        return "opencode"
    return "claude"


def pairs(ws: pathlib.Path, home: pathlib.Path, client: str, repo_scope: bool) -> list[tuple[str, pathlib.Path, pathlib.Path]]:
    """(kind, package source, destination on this machine) for everything the package ships."""
    out = []
    base = ws if repo_scope else home
    if client == "claude":
        sk, cmd, ag = base / ".claude/skills", base / ".claude/commands", base / ".claude/agents"
    else:
        sk = (ws / ".opencode/skills") if repo_scope else (home / ".config/opencode/skills")
        cmd, ag = sk, None
    for src in sorted((PKG / "skills").glob("*/SKILL.md")):
        out.append(("skill", src, sk / src.parent.name / "SKILL.md"))
    for src in sorted((PKG / "commands").glob("*.md")):
        dest = (cmd / src.stem / "SKILL.md") if client == "opencode" else (cmd / src.name)
        out.append(("command", src, dest))
    if ag is not None:
        for src in sorted((PKG / "agents").glob("*.md")):
            if src.name != "README.md":
                out.append(("agent", src, ag / src.name))
    scripts = ws / "05-automation/agent-manager/scripts"
    if scripts.is_dir() and not scripts.is_symlink():
        # copied, not linked: upgrade the copies file by file
        for src in sorted((PKG / "scripts").iterdir()):
            if src.is_file() and (src.suffix in (".py", ".md", ".sh", ".ps1") or src.name.endswith(".template")):
                out.append(("script", src, scripts / src.name))
    rub = rubrics_dir(ws)
    if rub and rub.is_dir() and not rub.is_symlink():
        for src in sorted((PKG / "rubrics").glob("*.yml")):
            out.append(("rubric", src, rub / src.name))
    return out


def rubrics_dir(ws: pathlib.Path) -> pathlib.Path | None:
    cfg = find_config(ws, None)
    if cfg:
        m = re.search(r'^\s*rubrics_dir:\s*"?([^"#\n]+?)"?\s*(#.*)?$', cfg.read_text(errors="replace"), re.M)
        if m:
            p = ws / m.group(1).strip()
            if p.exists():
                return p
    for c in ("06-skills/rubrics", "05-automation/agent-manager/rubrics"):
        if (ws / c).exists():
            return ws / c
    return None


def find_config(ws: pathlib.Path, explicit: str | None) -> pathlib.Path | None:
    if explicit:
        return pathlib.Path(explicit).expanduser()
    env = os.environ.get("MORNING_CONFIG")
    if env and pathlib.Path(env).is_file():
        return pathlib.Path(env)
    found = [p for p in (ws / "06-skills/skills").glob("agent-manager-config.*.yml")
             if "template" not in p.name and "engineer" not in p.name and "v4-additions" not in p.name]
    if len(found) == 1:
        return found[0]
    plain = ws / "06-skills/skills/agent-manager-config.yml"
    return plain if plain.is_file() else (found[0] if found else None)


# --------------------------------------------------------------------------- plan
def classify(src: pathlib.Path, dest: pathlib.Path) -> str:
    if dest.is_symlink():
        return "LINKED"
    if not dest.exists():
        return "NEW"
    if same(src, dest):
        return "SAME"
    return "STOCK" if shipped_before(dest) else "CUSTOM"


def top_blocks(text: str) -> list[str]:
    return re.findall(r"^([a-z_][a-z0-9_]*):", text, re.M)


def block_text(text: str, name: str) -> str:
    """The template's block `name:` with its leading comment banner, verbatim."""
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if re.match(rf"^{name}:", l))
    end = next((i for i in range(start + 1, len(lines)) if re.match(r"^[a-z_#]", lines[i])
                and not lines[i].startswith("  ")), len(lines))
    while end > start and not lines[end - 1].strip():
        end -= 1
    return "\n".join(lines[start:end])


def config_plan(cfg: pathlib.Path | None) -> dict:
    tpl = (PKG / "agent-manager-config.template.yml").read_text()
    if not cfg or not cfg.is_file():
        return {"config": None, "missing": [], "note": "no config found: setup-workspace.sh copies a starter"}
    have = set(top_blocks(cfg.read_text(errors="replace")))
    missing = [b for b in top_blocks(tpl) if b not in have]
    return {"config": cfg, "missing": missing, "suggest": cfg.with_name(cfg.stem + ".v4-additions.yml"),
            "text": tpl}


V4_RUNNER_MARKERS = ("--if-missing", "LOCKDIR", "NET_HOST")


def runner_plan(ws: pathlib.Path, client: str) -> dict:
    cands = [ws / "05-automation/agent-manager/run-prep.sh",
             ws / "05-automation/agent-manager/scripts/run-prep.sh",
             ws / "05-automation/agent-manager/scripts/run-prep.opencode.sh",
             ws / "05-automation/agent-manager/run-prep.opencode.sh"]
    have = next((c for c in cands if c.is_file() and not c.is_symlink()), None)
    tpl_name = "run-prep.opencode.template.sh" if client == "opencode" else "run-prep.template.sh"
    tpl = PKG / "scripts" / tpl_name
    if not have:
        return {"runner": None, "template": tpl}
    text = have.read_text(errors="replace")
    lacks = [m for m in V4_RUNNER_MARKERS if m not in text]
    m = re.search(r'^WORKDIR="([^"]+)"', text, re.M)
    return {"runner": have, "template": tpl, "lacks": lacks,
            "workdir": m.group(1) if m else str(ws), "suggest": have.with_name(have.stem + ".v4.sh")}


# --------------------------------------------------------------------------- apply
def backup(files: list[pathlib.Path], root: pathlib.Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    manifest = []
    for f in files:
        rel = str(f.resolve()).lstrip("/")
        dst = root / "files" / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dst)
        manifest.append({"original": str(f.resolve()), "saved": str(dst)})
    (root / "manifest.json").write_text(json.dumps({"made": dt.datetime.now().isoformat(timespec="seconds"),
                                                    "package": str(PKG), "files": manifest}, indent=2))


def restore(root: pathlib.Path) -> int:
    man = json.loads((root / "manifest.json").read_text())
    for row in man["files"]:
        dst = pathlib.Path(row["original"])
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(row["saved"], dst)
        print(f"  restored {dst}")
    added = root / "added.json"
    if added.exists():
        for p in json.loads(added.read_text()):
            pp = pathlib.Path(p)
            if pp.is_file():
                pp.unlink()
                print(f"  removed  {pp} (was added by the upgrade)")
    print(f"\n✓ restored {len(man['files'])} file(s) from {root}")
    return 0


def inject_name(src: pathlib.Path) -> str:
    """OpenCode needs `name:` in a command-as-skill; mirror install-skills.sh."""
    text = src.read_text()
    if text.startswith("---") and not re.search(r"^name:", text[:400], re.M):
        text = text.replace("---\n", f"---\nname: {src.stem}\n", 1)
    return text


# --------------------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--workspace", default=".")
    ap.add_argument("--home", default=str(pathlib.Path.home()))
    ap.add_argument("--client", choices=["claude", "opencode"])
    ap.add_argument("--repo-scope", action="store_true")
    ap.add_argument("--config")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--restore")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    if a.restore:
        return restore(pathlib.Path(a.restore).expanduser())

    ws = pathlib.Path(a.workspace).expanduser().resolve()
    home = pathlib.Path(a.home).expanduser()
    client = detect_client(a.client, home)
    plan = [(k, s, d, classify(s, d)) for k, s, d in pairs(ws, home, client, a.repo_scope)]
    cfgp = config_plan(find_config(ws, a.config))
    runp = runner_plan(ws, client)

    yours = []
    for kind, folder in (("skill", (home / ".claude/skills") if client == "claude" else (home / ".config/opencode/skills")),
                         ("command", home / ".claude/commands" if client == "claude" else None)):
        if folder and folder.is_dir():
            shipped = {s.parent.name for s in (PKG / "skills").glob("*/SKILL.md")} | {s.stem for s in (PKG / "commands").glob("*.md")}
            for p in sorted(folder.iterdir()):
                if p.name.startswith("."):
                    continue
                if p.stem not in shipped and p.name not in shipped:
                    yours.append(f"{kind}: {p.name}")

    if a.json:
        print(json.dumps({"workspace": str(ws), "client": client, "history": HAVE_HISTORY,
                          "files": [{"kind": k, "dest": str(d), "state": st} for k, s, d, st in plan],
                          "config_missing_blocks": cfgp.get("missing", []),
                          "runner": str(runp.get("runner")), "runner_lacks": runp.get("lacks", []),
                          "yours_untouched": yours}, indent=2))
        return 0

    print(f"\nMORNING LOOP UPGRADE to {VERSION}  ({'APPLY' if a.apply else 'dry run, nothing changes'})")
    print(f"package:   {PKG}")
    print(f"workspace: {ws}")
    print(f"client:    {client}")
    if not HAVE_HISTORY:
        print("note:      this package copy has no git history, so no file can be proven stock.\n"
              "           Every file that differs is treated as yours and kept. Clone with git for real upgrades.")
    groups: dict[str, list] = {}
    for row in plan:
        groups.setdefault(row[3], []).append(row)
    label = {"NEW": "added", "STOCK": "upgraded (was a stock copy; backed up first)",
             "CUSTOM": "KEPT AS YOURS, v4 written beside it as .v4-new",
             "SAME": "already current", "LINKED": "linked to a package, follows it"}
    for st in ("CUSTOM", "STOCK", "NEW", "LINKED", "SAME"):
        rows = groups.get(st, [])
        if not rows:
            continue
        print(f"\n{label[st]} ({len(rows)})")
        if st in ("SAME", "LINKED") and len(rows) > 6:
            print("  " + ", ".join(f"{k} {d.parent.name if d.name == 'SKILL.md' else d.name}" for k, s, d, _ in rows))
            continue
        for k, s, d, _ in rows:
            print(f"  {k:<8} {d}")
    if yours:
        print(f"\nyours, the package has no such file, never touched ({len(yours)})")
        print("  " + ", ".join(yours))

    print("\nconfig")
    if cfgp.get("config"):
        print(f"  {cfgp['config']}  (never edited)")
        if cfgp["missing"]:
            print(f"  v4 blocks it does not have yet: {', '.join(cfgp['missing'])}")
            print(f"  -> suggestions written to {cfgp['suggest'].name}; paste the ones you want.")
            print("     Without them the loop keeps doing exactly what it does for you today.")
        else:
            print("  has every block the template has")
    else:
        print(f"  {cfgp['note']}")

    print("\nscheduled runner")
    if runp.get("runner"):
        print(f"  {runp['runner']}  (never edited)")
        if runp["lacks"]:
            print("  it lacks the v4 catch-up, lock or network wait"
                  f" ({', '.join(runp['lacks'])})")
            print(f"  -> {runp['suggest'].name} written beside it with your WORKDIR filled in. Compare, then swap")
            print("     it in yourself (and load the catch-up job, see scripts/SETUP-DELIVERY.md).")
        else:
            print("  already has the v4 catch-up, lock and network wait")
    else:
        print("  none found in the workspace. See scripts/SETUP-DELIVERY.md to schedule the brief.")

    changing = [d for k, s, d, st in plan if st == "STOCK"]
    if not a.apply:
        print("\nNothing was changed. Re-run with --apply to do the above.")
        return 0

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    broot = ws / "05-automation/agent-manager/backups" / f"pre-{VERSION}-{stamp}"
    backup(changing, broot)
    added = []
    for k, s, d, st in plan:
        if st in ("SAME", "LINKED"):
            continue
        d.parent.mkdir(parents=True, exist_ok=True)
        body = inject_name(s) if (client == "opencode" and k == "command") else s.read_text()
        if st == "CUSTOM":
            beside = d.with_name(d.name + ".v4-new")
            beside.write_text(body)
            added.append(str(beside))
            continue
        if st == "NEW":
            added.append(str(d))
        d.write_text(body)
        if s.stat().st_mode & 0o111:
            d.chmod(d.stat().st_mode | 0o111)
    if cfgp.get("missing"):
        parts = [f"# v4 blocks your config does not have yet, generated {stamp}.",
                 "# Your config was NOT edited. Copy the blocks you want into it.", ""]
        parts += [block_text(cfgp["text"], b) + "\n" for b in cfgp["missing"]]
        cfgp["suggest"].write_text("\n".join(parts))
        added.append(str(cfgp["suggest"]))
    if runp.get("runner") and runp["lacks"]:
        t = runp["template"].read_text().replace("<PATH TO YOUR WORKSPACE>", runp["workdir"])
        runp["suggest"].write_text(t)
        runp["suggest"].chmod(0o755)
        added.append(str(runp["suggest"]))
    (broot / "added.json").write_text(json.dumps(added, indent=2))
    print(f"\n✓ done. Backup of everything replaced: {broot}")
    print(f"  Undo all of it: python3 {PKG}/scripts/upgrade.py --restore {broot}")
    print("  Next: restart Claude Code (agents load at session start), then run the doctor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
