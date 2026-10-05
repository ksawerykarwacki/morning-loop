# Instructions for an AI assistant working in this repo

You are probably here because someone asked you to review the morning loop, install it, or upgrade their existing setup to v4. Their setup is their work: skills they tuned, scripts they patched, a config that describes their job, a runner that wakes their laptop. **Your first duty is to not damage any of it.** Read this whole file before you run anything.

## Which situation is this?

Check before you act, and say what you found:

- **Existing setup:** any of `~/.claude/commands/morning.md`, `~/.config/opencode/skills/morning/`, a folder containing `05-automation/agent-manager/` or `06-skills/skills/agent-manager-config.*.yml`, or a loaded launchd job / scheduled task whose name contains `morning`. Ask the person where their workspace is if you can't find it. **Follow "Upgrading" below.**
- **Nothing found:** a first install. Follow `ADOPT-MORNING.md` and use `scripts/setup_workspace.py --role <preset>` (see "Fitting it to the person").
- **Only asked to review:** read `V4-WHATS-NEW.md`, `README.md` and `roles/README.md`, and answer from them. Claim only what `V4-WHATS-NEW.md` says shipped; `docs/history/V3-TO-V4.md` is a proposal list, and much of it is deferred.

## Upgrading an existing setup

1. **Pull, then dry-run.** `git pull`, then `python3 scripts/upgrade.py --workspace <their workspace>`. Add `--client opencode` for OpenCode. The dry run changes nothing. Show the plan in plain words: what gets upgraded, what is theirs and kept, what is new.
2. **Ask before applying.** Run `--apply` only after the person says yes. It writes one backup folder and prints the `--restore` command; tell them where it is.
3. **Never hand-copy package files over theirs, and never run `install-skills.sh` as the first step of an upgrade.** `upgrade.py` decides stock versus customized with git; you can't do that by eye. Never delete `.v4-new`, `.before-v4` or backup files, and never run `git reset`, `git clean` or `git checkout --` in their workspace.
4. **`.v4-new` files are a conversation, not a task.** Each one sits beside a file they changed. Show the diff, explain what v4 adds, propose a merge that keeps their changes, and write it only with their approval. Leaving their version as it is is a fine answer.
5. **Their config is never edited without them.** `*.v4-additions.yml` holds the v4 blocks they lack. Walk through them one at a time: what each block does and whether it fits their work. Paste only the ones they choose, into their own config.
6. **Their runner is never swapped without them.** Show the diff between their `run-prep.sh` (or `.ps1`) and `run-prep.v4.sh`, point out their own customizations, carry those over into the v4 version, and swap only on a yes. Then load the catch-up job (`scripts/SETUP-DELIVERY.md`) and verify that two jobs are scheduled.
7. **Verify.** Remind them to restart Claude Code (agents load at session start). Run the doctor from their workspace (`python3 05-automation/agent-manager/scripts/doctor.py`), then one supervised `/morning`. Compare the brief with their last one and point out what changed.
8. **If anything breaks:** `python3 scripts/upgrade.py --restore <backup folder>` puts every replaced file back and removes what was added. Offer it before trying to fix things by hand.

## Fitting it to the person

The loop began as one product owner's loop. v4 shapes it to the person running it.

- **Pick the role preset with them.** Read their `CLAUDE.md`, their memory and their JTBD doc if they have one, then propose one of `roles/*.yml` (`roles/README.md` lists them) and say why. Set it as `owner.role_profile`; it decides what the brief leads with and which sections are noise for them. Ask; don't assume a title means a preset.
- **Routing is theirs.** A preset only seeds a fresh config. For an existing config, suggest rules from the preset that match jobs they actually do, and leave the rest.
- **Don't invent drafters.** If a job of theirs has no shipped skill, write the rule commented out, with the reason. A drafter without a rubric and real examples produces confident text nobody can grade. After a week of briefs, `/jtbd-capture` turns their real jobs into routing, and `CONTRIBUTING.md` explains how a personal skill becomes a shared one.
- **Their own tools belong in their config.** If they have their own skill, script or digest, wire it in as a rule rather than replacing it with a package one.

## Platform notes

- **Mac:** everything works as documented.
- **Windows:** the `.sh` scripts need zsh. Use `python scripts\setup_workspace.py` and `python scripts\upgrade.py`, then `SETUP-DELIVERY.md` "Scheduling the run (Windows)". The Windows runner hasn't been run on a real Windows machine yet; say so, and do the first run supervised.
- **OpenCode:** pass `--client opencode`. Commands install as skills.

## Things to say plainly

- The brief is made on their computer, so it arrives when the computer is on: at 07:52, or the first time it's opened that morning before 12:00.
- Nothing leaves their machine without their per-item yes: no ticket, post or page.
- This is a beta. The known issues are listed in `V4-WHATS-NEW.md`.
