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

## Per-version migration dispositions (1.0.0 -> 1.4.2)

<!-- Written by PLAN step 4, one row per version step. -->
