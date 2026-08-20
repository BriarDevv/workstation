# claude/ layer becomes canonical + AE/1.0.0 -> 1.4.2 — decisions

## 2026-08-20 — SPEC approved design-first; parent ruled the two open calls

Design-first `work-plan` wrote SPEC.md and stopped at its approval gate.
The owner's seat for this lane is the parent orchestrator, so approval was
taken through `orca orchestration ask`, not a local prompt. Verdict: **SPEC
approved as written**, plus two rulings.

### Ruling A — apply migration note 1.3.0's installer sweep

Note 1.3.0 reads "the workstation installer must sweep the dangling fan-out
junction". This repo *is* that installer, and `claude/install.ps1` has no
sweep of any kind — it only creates or replaces junctions, so a junction
whose source skill disappears survives every re-run. The live machine
happens to be clean already (no `fan-out` junction present under
`~/.claude/skills/`), but the latent gap is real.

**Ruling: APPLY, as a dangling-ONLY sweep** — remove a junction under
`~/.claude/skills` only when its `LinkTarget` no longer exists on disk.
Deliberately **not** a "remove anything not in `$skillSources`" purge: that
would delete `claude-dual-account-setup`, which `accounts/install.ps1`
owns and `claude/install.ps1` must never touch. Plus one guard test in
`tests/run.ps1`.

**Why it matters beyond this lane:** the parent noted the gap is already
tracked as **MAT-50** ("installer leaves dangling skill junctions after a
rename — sweep stale links on apply"), and this design matches its intent,
including leaving `claude-dual-account-setup` alone. The PR therefore
carries `Closes MAT-50` alongside `Closes MAT-110`.

### Ruling B — skip migration note 1.3.1's optional `Tracker:` line

Note 1.3.1 offers an optional one-line tracker declaration
(`Tracker: Linear — workspace bygama · team MAT`) directly under the stamp.
`AGENTS.md` sits at 59 lines against a 60-line target, and the declaration
costs two lines (itself plus its separating blank), pushing the root entry
file to 61 — a `medium` lint finding traded for an optional line.

**Ruling: SKIP.** Trimming `AGENTS.md` to make room is out of scope for a
migration lane. Recorded here rather than silently omitted; a later lane
that has budget to spend may adopt it.

## 2026-08-20 — step 3's acceptance predicate was mis-specified; corrected to `= 2`

PLAN step 3 asked for `grep -c 'claude-dual-account-setup' AGENTS.md` = 1.
Step 3's implementer stopped before committing and reported that the count is
**2**, and was already 2 at HEAD before its edit: once in the exception clause
of the gotcha it was rewriting, once in the unrelated "the dual-account launcher
block exists in THREE synced copies" gotcha
(`accounts/skills/claude-dual-account-setup/profile-functions.ps1`).

Satisfying `= 1` literally would have required either dropping the exception
clause the step was explicitly told to keep, or editing an out-of-scope gotcha.
Both are wrong; the predicate was.

**Ruling: the predicate is corrected to `= 2`, and specifically to *unchanged
from baseline*** — `git show HEAD:AGENTS.md | grep -c ...` equals the
post-edit count. That equality is what the predicate was always meant to prove:
the exception clause survived AND the launcher gotcha took no collateral edit.
PLAN.md's step-3 line is amended in place to say so; the implementer was
unblocked and told to record the corrected predicate in its report.

Controller error, caught by the implementer refusing to guess — recorded here
rather than silently patched.

## Per-version migration dispositions (1.0.0 -> 1.4.2)

`AE/1.0.0` is the stamp this repo carried, so the ten steps below are the
ones this lane crosses. Source: the "Per-version notes" section of
`ae-init/references/migration.md`, measured against the repo at this lane's
HEAD. That file lists `1.4.2` before `1.4.1`; the table is in numeric order.

| Step | Disposition | Why, and what was checked |
|---|---|---|
| 1.1.0 | **applied** — `docs/tiers.md` refresh | Note: restamp + optionally refresh `docs/tiers.md`, whose L row gains the recommended-executor mention. Refresh done in this step; the refreshed L row reads "recommended executor: the `work-run` skill or `orchestrate` (parent-bound) — fresh subagent per PLAN step". |
| 1.2.0 | **not-applicable** — restamp only | The note says so in its own words (skills are machine-global junctions; the SessionStart hook applies via the workstation installer). This repo *is* that installer, so the hook half was checked rather than assumed: `claude/hooks/using-ae.ps1` exists and `claude/hooks.json` registers it under `SessionStart`, installed by `claude/install.ps1` (hooks loop, `hooks.json` merge). Already discharged before this lane (commit `d95900d`); no repo file owes a change. |
| 1.2.1 | **applied** — same `docs/tiers.md` refresh | Note: restamp + optional refresh, the L row now naming `work-run`. Satisfied by the same overwrite as 1.1.0 — the refreshed L row names `work-run`. |
| 1.2.2 | **not-applicable** — restamp only | Restamp-only by the note's own words: the templates + shaping package ships as machine-global skills. Checked: the repo vendors no skill of its own except `accounts/skills/claude-dual-account-setup`, which `accounts/install.ps1` owns and this lane never touches. |
| 1.3.0 | **applied** — in two parts | (a) The `fan-out` -> `orchestrate` rename: the `AGENTS.md` tier one-liner now reads `XL orchestrate` (rewrapped in this step to keep the phrase on one line), and the refreshed `docs/tiers.md` XL row reads `mandatory orchestrate`. (b) "the workstation installer must sweep the dangling fan-out junction" — **applied per Ruling A above**, as a dangling-only sweep plus a guard test, carrying `Closes MAT-50`. Implemented by **PLAN step 5**, not by this step; `claude/install.ps1` and `tests/run.ps1` were deliberately left untouched here. |
| 1.3.1 | **skipped** — the optional `Tracker:` line | **Ruling B above**, not re-decided here: the declaration costs two lines against a 60-line target that `AGENTS.md` already fills to 59. `AGENTS.md` is 59 lines after this step; no `Tracker:` line was added. |
| 1.3.2 | **not-applicable** — restamp only | Restamp-only by the note's own words: the fix lives inside the child dispatch template, a machine-global skill asset. Nothing inside an installed repo. |
| 1.4.0 | **applied** — `docs/tiers.md` refresh; optional adoptions **not-applicable** | Required half: the template's closing pointer-home paragraph is present after the overwrite. Optional adoptions, each checked: (i) nested `AGENTS.md` at earned depth — the repo already nests exactly one (`git ls-files '*AGENTS.md'` returns only the root and `terminal/AGENTS.md`) and this lane earns no new depth; (ii) `Tracker-project:` lines presuppose the `Tracker:` declaration Ruling B skipped, so they are moot; (iii) the runtime-neutral browser gotcha is for UI repos — this repo restores Windows configuration and ships no browser-driven surface. |
| 1.4.1 | **not-applicable** — restamp only | Both optional pickups are lint *relaxations*, so neither owes an edit, and neither has a subject here: (i) a pointer hosting a fenced tool-managed block — both pointers (`CLAUDE.md`, `terminal/CLAUDE.md`) are the single line `@AGENTS.md`, no fence; (ii) an `AGENTS.md` citing a command path outside the repo — the Commands block cites only `./install.ps1` and `./tests/run.ps1`, both repo-relative. |
| 1.4.2 | **not-applicable** — restamp only; the new lint check is inert here | Verified in the check's own source rather than taken from the note. `agent-lint.mjs` defines `const SHIPPED_SURFACE = /^(skills\|reference\|templates\|global\|loops)\//` and filters its file list through it; the walk builds every path as `relative(root, full).replaceAll("\\", "/")`, i.e. root-relative with forward slashes — so the `^` anchor really is the repo root. This repo has no root-level `skills/`, `reference/`, `templates/`, `global/` or `loops/` (root `ls`; `git ls-files` filtered on those names returns only `accounts/skills/claude-dual-account-setup`, whose path starts `accounts/` and misses the anchor). Independent confirmation: this lane's own `SPEC.md` and `PLAN.md` are full of `C:/Briar/...` machine paths and lint still reports `0 high, 0 medium, 0 low` — the check demonstrably does not sweep the whole repo. |

Restamp-only dispositions are the note's own verdict, not a dodge: where a
release changed only machine-global skills or AE's own templates, an
installed repo's sole obligation is the stamp — which this step performed
(`Standard: AE/1.4.2`).
