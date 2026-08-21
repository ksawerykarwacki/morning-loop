# Adoption log

**The one thing the reusability KR measures, and the only place it is recorded.**

The workflow playbook records authorship: roughly 70 entries, every one "added by {self}". Its entry
standard has no field for who else used it, so four months of cataloguing produced zero evidence of
adoption. This file is that field.

**The bar:** used successfully by at least one other squad member **without help from the author.**

## Rules

1. **The runner writes the row, never the author.** An author logging their own adoption is what made
   the playbook useless.
2. **"Needed author?" is the whole point.** Asked them a question, patched their code, pinged them on
   Mattermost: that is a `yes`. Still useful, just not L2 yet.
3. **Record failures.** "Tried it, would not run on Windows" is worth more than an empty row.
4. **One row per person per skill**, not per run. Update the row rather than adding another.

## Log

| skill / tool | author | who ran it | date | worked? | needed author? | notes |
|---|---|---|---|---|---|---|
| `/km-workflow-push` | Maria Sommer | Andres, Xitong, Daniel Zhu, David, Mathieu, Jasmine, Chris, Tomek | 2026-05-28 → 06-12 | yes | no | Backfilled 2026-08-20 from KM-12215: 8 non-authors posted skill-generated output and created real Confluence pages, no help request in 37 comments. **Inferred from artifacts, not testimony** |
| `/morning` core (v1) | Tomek Duda | Xitong Deng | 2026-07-22 | yes | no | *"I never modified /morning itself, config only"*, 7/7 drafts verifier-READY. Had to symlink command files himself |
| `/morning` core (v2) | Tomek Duda | Daniel Zhu | 2026-08-17 | yes | no | 2 confirmed unattended fires. Self-fixed a headless `--model` pin |
| `/morning` core (v2) | Tomek Duda | Andres Cagua | 2026-08-17 | yes | no | First unattended run after 13 self-made fixes across two sessions |
| `/morning` core (v2) | Tomek Duda | Maria Sommer | 2026-08-12 | partial | no | Windows: ported `notify.py`, fixed a UTF-8 crash. Never delivered unattended by the scheduler alone |
| `/morning` core (v2) | Tomek Duda | David Predusel | 2026-08-18 | **no** | n/a | 12 scheduled runs, zero drafts ever produced. Blocked on an org admin enabling Rovo API-token auth, not on the loop |
| `ticket-brief` dev drafter | Xitong Deng | — | — | — | — | **Awaiting a second user.** Works for the author; was not in the package until v3.1 |
| CM daily loop | Chris Gamrot | — | — | — | — | **Awaiting a second user.** 21/21 unattended for the author. Sole-operator by design |
| `ac-timesheet` | Andres Cagua | — | — | — | — | **Offered 2026-08-20**, no adopter yet |
| `ac-email-digest` | Andres Cagua | — | — | — | — | **Offered 2026-08-20**, no adopter yet |

## Honest count, 2026-08-21

**Meeting the L2 bar: 1** (`/km-workflow-push`, and on inferred rather than testimonial evidence).
**Meeting it with an asterisk: 1** (the `/morning` core, where every adopter had to patch the author's
code first, which passes the letter of "without help from the author" and not its spirit).
**Awaiting a first outside user: 4.**

The four waiting are the fastest route to a real number, and three of them already work.
