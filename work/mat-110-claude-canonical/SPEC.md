---
issue: MAT-110
---
# claude/ layer becomes canonical + AE/1.0.0 -> 1.4.2 — spec

<!-- Owner-written (parent orchestrator's dispatch brief). The agent never edits this file. -->

## Ruling this lane implements

Owner ruling, 2026-08-20: the **personal machine layer's canonical home is
this repo (workstation)**, not Agent-Engineering. AE is the methodology
others adopt; personal policy (accounts, language, hooks) is the owner's.
AE's `global/` is deleted right after this lane merges (MAT-111) — until
then it still exists, is read from, and is never modified.

## What done looks like

1. **`claude/CLAUDE.md` is canonical.** Its body is synced from
   `Agent-Engineering/global/CLAUDE.md` at merged main (commit `4da691f`),
   which carries today's MAT-109 language rules — the
   "Reply in the language of each prompt" bullet must be present. Its
   header comment reads
   `Canonical: workstation/claude/CLAUDE.md — applied to ~/.claude/CLAUDE.md by claude/install.ps1.`
   The file stays within the 40-line global-CLAUDE.md cap.

2. **`claude/hooks/orca-probe.ps1` and `claude/hooks/using-ae.ps1` are
   canonical.** Bodies synced from AE `global/hooks/` (already byte-identical
   modulo the repo's CRLF convention); each header comment flips to
   `Canonical: workstation/claude/hooks/<name> — applied to ~/.claude/hooks/ by claude/install.ps1.`
   `global/hooks/README.md` is **not** brought over — it is standard
   doctrine and moves to AE's `reference/` under MAT-111.

3. **The root `AGENTS.md` gotcha flips.** It no longer calls
   `claude/CLAUDE.md` a SYNCED COPY with canon in Agent-Engineering; it
   states that `claude/CLAUDE.md` and `claude/hooks/` are CANONICAL here
   (the personal machine layer). The skills junction sentence in that same
   gotcha — junction-linked from `Agent-Engineering` and `skills` by
   `claude/install.ps1`, except `claude-dual-account-setup` from
   `accounts/` — stays true and stays in place.

4. **The repo stamp migrates `AE/1.0.0` -> `AE/1.4.2`.** Every version step
   in `skills/ae-init/references/migration.md` is dispositioned, and the
   judgment (applied / not-applicable + why) is recorded per step in
   `DECISIONS.md`. `Standard: AE/1.4.2` in `AGENTS.md`.

## Migration dispositions proposed

Measured against the repo (audit run 2026-08-20, `agent-lint` PASS at the
old stamp). Restamp-only steps carry no repo change by the note's own words.

| Step | Note | Disposition |
|---|---|---|
| 1.1.0 | restamp; optionally refresh `docs/tiers.md` (L row gains recommended-executor) | **apply** — folded into the 1.4.0 template refresh |
| 1.2.0 | restamp only (skills are machine-global) | restamp |
| 1.2.1 | restamp; optionally refresh `docs/tiers.md` (L row names work-run) | **apply** — same refresh |
| 1.2.2 | restamp only | restamp |
| 1.3.0 | restamp; **the workstation installer must sweep the dangling fan-out junction** | **apply** — this repo *is* the workstation installer, and `claude/install.ps1` has no such sweep; also the AGENTS.md tier one-liner `XL fan-out` -> `XL orchestrate` |
| 1.3.1 | restamp; optional one-line `Tracker:` declaration in AGENTS.md | **open — parent's call** (see Open question) |
| 1.3.2 | restamp only | restamp |
| 1.4.0 | restamp + refresh `docs/tiers.md` from the template; optional nested AGENTS.md / browser gotcha | **apply** the template refresh; optional adoptions not applicable (no new earned depth; not a UI repo) |
| 1.4.1 | restamp; two optional pickups | restamp — pickups not applicable (no fenced tool-managed block; no out-of-repo command paths in AGENTS.md) |
| 1.4.2 | restamp; the new machine-path lint check fires only on repos vendoring `skills/`, `reference/`, `templates/`, `global/` or `loops/` at the repo root | restamp — check is inert here (`SHIPPED_SURFACE` is root-anchored; this repo's only `skills/` is nested under `accounts/`) |

## Open question for the parent

1.3.1's `Tracker:` declaration is explicitly optional and costs two lines
(the line plus its blank) directly under the stamp. `AGENTS.md` is at
**59 of its 60-line target**, so adopting it makes the root entry file 61
lines — a `medium` lint finding traded for an optional declaration. The
lane's default is **not to adopt**, recorded as such; the parent may rule
the other way.

## Out of scope

- Any change to the Agent-Engineering repo (MAT-111 owns `global/`'s removal).
- Any write to the live `~/.claude` — repo files only; the parent applies the
  canonical content after merge.
- `secrets/`, `accounts/` and the dual-account launcher's three synced copies,
  `terminal/` ASCII fastfetch assets, `windows/debloat.ps1`.

## Verification bar

- `pwsh ./tests/run.ps1` exits 0 after any script change.
- `node <AE>/scripts/agent-lint.mjs .` reports **0 high**.
- `pwsh ./install.ps1 claude -WhatIfOnly` shows zero tracked or user-config
  writes after the restore-path change.
