# Drafter Rubrics

Per-skill quality rubrics for the morning-loop verify stage (`/morning` Phase 3b). Each drafter skill
has a rubric here; the judge subagent grades a draft **check by check** (pass/fail + one-sentence reason)
instead of assigning one vibe score, and the revise loop is handed the *specific* failed checks to fix.

This is Path A of the morning-routine expansion (systems leverage / rubrics-over-prompts). It slots into
the existing `quality:` machinery in `agent-manager-config.yml` (`bar`, `max_revisions`,
`stricter_for_external`, independent verifier), it does not replace it.

## Resolution
Skill `X` → `06-skills/rubrics/X.rubric.yml`. Every skill rubric **extends `_base.rubric.yml`** (the
universal checks). If no skill rubric exists, the verifier falls back to `_base` alone. The path root is
`paths.rubrics_dir` in the config.

## Schema (per the ladders-of-leverage article)
```yaml
schema_version: 1
extends: _base                 # skill rubrics inherit the base checks
task: "one line — what this drafter produces"
calibration_target: "who the output must satisfy (e.g. 'a GC stakeholder, ship-as-is')"
created: YYYY-MM-DD
goldens:                       # the examples the checks were calibrated against
  - path: "...good example..."
    note: "why it's golden"
known_reject:                  # an example (or described anti-pattern) the rubric MUST fail
  - "flat description of a bad output the checks should catch"
checks:
  - id: snake_case_id
    type: structural | binary_llm      # structural = mechanically checkable; binary_llm = judgment
    severity: block | gate | normal     # block = fail = hard NEEDS-EDIT (never shippable, e.g. invented facts)
                                         # gate  = the ship test itself
                                         # normal = contributes; revisable within max_revisions
    scope: voice | format | data         # voice = format-independent; format = tied to current output format
    statement: "the check, phrased so a grader returns pass/fail"
    rationale: "why this is a check — tie to a golden example or a known failure"
```

## Grading contract (what the verifier does)
1. Resolve the skill's rubric = `_base` checks + skill checks.
2. For each check, run the article's grader prompt: *"Apply this single check to the artifact. Return pass | fail and one sentence why."*
3. `READY` iff **every** check passes. Any `block`-severity fail = hard NEEDS-EDIT regardless of revisions.
4. On any fail within `max_revisions`, hand the drafter back the **failed checks' statements + reasons** (not a vibe note) for one revision, then re-grade.
5. Log per-skill pass-rate + the check that failed most (feeds `focused-skill-improvements.md`).

## Calibrating a new rubric
Draft the checks from the skill's spec + 1-3 golden outputs, then test: the rubric must **accept** the
goldens and **reject** the `known_reject`. If it passes a bad example or fails a golden, fix the check,
not the example.
