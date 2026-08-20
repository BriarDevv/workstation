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

<!-- Written by PLAN step 4, one row per version step. -->
