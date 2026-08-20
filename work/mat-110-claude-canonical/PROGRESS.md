# claude/ layer becomes canonical + AE/1.0.0 -> 1.4.2 — progress

Tier M · executed by `work-run` (fresh implementer + fresh reviewer per
PLAN step) in this worktree, branch `bygama/mat-110-claude-canonical`.

## Baseline (2026-08-20, before any step)

`ae-audit` against AE/1.4.2, repo stamped `AE/1.0.0`:

```
$ node C:/Briar/repos/mine/Agent-Engineering/scripts/agent-lint.mjs .
agent-lint C:\Users\mateo\orca\workspaces\workstation\mat-110-claude-canonical
0 high, 0 medium, 0 low — PASS
```

Judgment findings (score 5.5/10 — all of them version drift this lane closes):

| Severity | File | Finding |
|---|---|---|
| medium | `AGENTS.md` | stamp `AE/1.0.0`, ten releases behind `AE/1.4.2` |
| medium | `docs/tiers.md` | stale vs template: no recommended-executor mention (1.1.0/1.2.1), XL row still `mandatory fan-out` (1.3.0), no closing pointer-home line (1.4.0) |
| medium | `claude/CLAUDE.md` | behind AE `global/CLAUDE.md`: missing the MAT-109 language-mirroring rule, still carries a long-lived-process bullet AE trimmed on 2026-08-20 |
| medium | `claude/install.ps1` | no dangling-junction sweep — a junction whose source disappears survives re-runs (note 1.3.0) |
| low | `AGENTS.md:22` | tier one-liner says `XL fan-out`; 1.3.0 renamed it `XL orchestrate` |
| low | `AGENTS.md:26` | gotcha declares `claude/CLAUDE.md` a SYNCED COPY, contradicting the 2026-08-20 ruling |

Byte-level baseline: `claude/hooks/*.ps1` are already content-identical to
AE's `global/hooks/*.ps1` (the full-file `diff` differs only because the
repo checks `*.ps1` out as CRLF per `.gitattributes`) — step 2 is a
header-comment flip, not a content sync.

## Done

<!-- One implementer report per PLAN step, appended by that step's runner. -->

### Step 1 — `claude/CLAUDE.md` synced from AE `global/CLAUDE.md`, canon header flipped

Replaced the body of `claude/CLAUDE.md` with AE `global/CLAUDE.md`'s content
(picking up the MAT-109 language-mirroring rules and dropping the
long-lived-process bullet AE already trimmed), then set line 3's HTML
comment to
`<!-- Canonical: workstation/claude/CLAUDE.md — applied to ~/.claude/CLAUDE.md by claude/install.ps1. -->`.
Content copied via `sed` (line 3 rewritten) piped through `sed 's/$/\r/'` to
land as CRLF, preserving the repo's existing working-tree convention —
`file claude/CLAUDE.md` confirms CRLF line terminators after the edit.

Files changed: `claude/CLAUDE.md`.

Acceptance (run from the repo root):

```
$ diff <(sed '3d' claude/CLAUDE.md) <(sed '3d' C:/Briar/repos/mine/Agent-Engineering/global/CLAUDE.md)
(empty, exit 0)

$ diff <(sed '3d' claude/CLAUDE.md | tr -d '\r') <(sed '3d' C:/Briar/repos/mine/Agent-Engineering/global/CLAUDE.md)
(empty, exit 0)

$ grep -c 'Reply in the language of each prompt' claude/CLAUDE.md
1

$ awk 'END{print NR}' claude/CLAUDE.md
40

$ node C:/Briar/repos/mine/Agent-Engineering/scripts/agent-lint.mjs .
agent-lint C:\Users\mateo\orca\workspaces\workstation\mat-110-claude-canonical
0 high, 0 medium, 0 low — PASS
```

Note on the diff: the raw (non-normalised) `diff <(sed '3d' claude/CLAUDE.md) <(sed '3d' .../global/CLAUDE.md)`
already printed nothing and exited 0 in this Git Bash environment — process
substitution here didn't surface a CRLF-vs-LF difference on its own. Ran
the `tr -d '\r'`-normalised form as well per the step's note; it also
printed nothing. Both forms agree; reporting both for the record.

Line count landed exactly at the 40-line cap (not under it) — same as AE's
source file, so no further trimming was needed or done.

No concerns. Committed `1ffdeb5` — `feat(claude): sync claude/CLAUDE.md body from AE global/CLAUDE.md, flip canon header`.

#### Step 1 review — fresh reviewer, verdict verbatim

```
### Spec compliance
✅ Compliant

All four acceptance predicates verified directly:
- `diff <(sed '3d' claude/CLAUDE.md) <(sed '3d' .../global/CLAUDE.md)` — empty
- `grep -c 'Reply in the language of each prompt' claude/CLAUDE.md` — 1
- `awk 'END{print NR}' claude/CLAUDE.md` — 40 (≤40)
- `node .../agent-lint.mjs .` — `0 high, 0 medium, 0 low — PASS`, exit 0

(a) Removal of the four-line "long-lived process" bullet — faithful consequence,
not scope creep. AE's global/CLAUDE.md has no such bullet at all; the deletion is
exactly what a body-replace-from-source requires, confirmed by the whole-file diff
coming back empty.
(b) Canon-comment text, character for character — exact match, including the em
dash (U+2014) and trailing period. Verified via `cat -A` byte comparison.
(c) Line endings/encoding — preserved correctly. Working-tree file is CRLF; the
git blob at HEAD is normalized LF, matching `.gitattributes` (`* text=auto`) for
every text file in this repo.

The diff touches only `claude/CLAUDE.md` — no collateral edits.

### Issues
#### Critical (Must Fix)
None.
#### Important (Should Fix)
None.
#### Minor (Nice to Have)
None.

### Assessment
**Step quality:** Approved
**Reasoning:** A mechanical content-sync step, verified mechanically — all four
stated acceptance predicates pass, the canon-comment text matches the PLAN
literally, the dropped bullet is a correct consequence of the source it synced
from (not an unrequested deletion), and the CRLF working-tree convention was
preserved per the lane's Constraints block.
```

Controller note: the reviewer's report did not arrive over the agent message
channel (it went idle twice without delivering). It was recovered by having the
reviewer write the report to a session scratch file, read back and pasted above
verbatim. No fix round — zero Critical/Important/Minor findings. Step 1 closed.

### Step 2 — hooks' canon headers flipped, `[batch]` orca-probe.ps1 + using-ae.ps1

Rewrote only the `# Canonical: …` sentence in both hook headers to the
step-1 format with dest `~/.claude/hooks/`:

- `orca-probe.ps1`: `# Canonical: Agent-Engineering/global/hooks/orca-probe.ps1 — applied to\n# ~/.claude/hooks/ by the workstation installer. Executing skills may cite` ->
  `# Canonical: workstation/claude/hooks/orca-probe.ps1 — applied to\n# ~/.claude/hooks/ by claude/install.ps1. Executing skills may cite`
- `using-ae.ps1`: `# under one header line. Canonical: Agent-Engineering/global/hooks/using-ae.ps1\n# — applied to ~/.claude/hooks/ by the workstation installer. The skill file` ->
  `# under one header line. Canonical: workstation/claude/hooks/using-ae.ps1\n# — applied to ~/.claude/hooks/ by claude/install.ps1. The skill file`

Every other sentence in both header blocks (what the hook does, the
step-0 probe note, the single-source-of-truth note) is untouched; line
count and wrap points are unchanged from the original (4 lines / 6 lines).
`global/hooks/README.md` was not copied (never existed in `claude/hooks/`
to begin with; confirmed absent post-edit).

**Tooling gotcha:** the obvious approach — `sed` (piped or `-i`, including
inside process substitution) — silently strips every `\r` in this Git Bash
environment, on touched *and* untouched lines alike, corrupting the file to
mixed/LF line endings. Caught it by `od -c`'ing the result before trusting
it, discarded that attempt (`git checkout --`), and redid the edit with
`perl -0777 -i -pe 's/.../.../'` (byte-safe, no `-C` flag — adding `-CSD`
actually broke the em-dash byte match, so plain `perl -0777` is what's
needed), which leaves every `\r\n` — touched or not — byte-identical.
Verified with `perl -ne '... unless /\r\n$/'` (no output on either file,
i.e. every line ends `\r\n`) and a body-only diff against `git show
HEAD:<file>` (with `\n`->`\r\n` reinserted) coming back empty for both
files.

Files changed: `claude/hooks/orca-probe.ps1`, `claude/hooks/using-ae.ps1`.

Acceptance (run from the repo root):

```
$ grep -rc 'Canonical: Agent-Engineering' claude/
(every file: 0; sum 0)

$ for f in orca-probe using-ae; do diff <(grep -v '^#' claude/hooks/$f.ps1 | tr -d '\r') <(grep -v '^#' C:/Briar/repos/mine/Agent-Engineering/global/hooks/$f.ps1); done
(empty, exit 0, both files)

$ test ! -e claude/hooks/README.md && echo "OK: absent"
OK: absent

$ pwsh ./tests/run.ps1
=== Result
  26 passed, 0 failed
(exit 0)
```

`git status --short` after the commit shows only the two intended files
touched (`git diff --stat`: 2 files changed, 4 insertions, 4 deletions —
i.e. exactly the two rewrapped lines per file).

No concerns beyond the sed gotcha noted above (worked around, not left
unresolved). Committed `8d80b7b` —
`feat(claude): flip canon header on orca-probe.ps1 and using-ae.ps1`.

#### Step 2 review — fresh reviewer, verdict verbatim

```
### Spec compliance
✅ Compliant

- `grep -rc 'Canonical: Agent-Engineering' claude/` → every file reports `:0`.
- per-file body diff vs the AE source → both empty (exit 0). Every non-comment
  (executable) line is byte-identical to the AE canonical source.
- `test ! -e claude/hooks/README.md` → absent, confirmed.
- `pwsh ./tests/run.ps1` → 26 passed, 0 failed, exit 0. (One `[!]` line,
  "Package update check failed (winget exit 37)", is a pre-existing
  network/winget-availability check unrelated to this diff.)

Additional checks: header-only edit verified byte-identical elsewhere; canon text
exact in both files with each path self-referential (not swapped); em dash
byte-grepped as UTF-8 U+2014 in both; CRLF preserved — orca-probe.ps1 19/19 and
using-ae.ps1 14/14 lines end in CR, ruling out the sed-strips-CR failure mode;
diff touches only these two files, one hunk each.

### Issues
None found — no Critical, Important, or Minor items.

### Assessment
**Step quality:** Approved
**Reasoning:** All four mechanical accept-criteria commands were run directly and
pass; independent verification of CRLF bytes, the em dash character, and
header-only scope found no deviation. Clean, minimal, purely mechanical edit.
```

No fix round — zero findings. Step 2 closed.

### Step 3 — root `AGENTS.md` gotcha flipped from SYNCED COPY to CANONICAL

Rewrote only the gotcha bullet at (pre-edit) lines 26-30, from declaring
`claude/CLAUDE.md` a SYNCED COPY with canon in Agent-Engineering, to
stating `claude/CLAUDE.md` and `claude/hooks/` are CANONICAL here — the
personal machine layer, applied to `~/.claude` by `claude/install.ps1`.
The skills-junction sentence (`Agent-Engineering` + `skills` sources via
`claude/install.ps1`, except `claude-dual-account-setup` from `accounts/`
linked by `accounts/install.ps1`) is carried over unchanged in substance,
just re-wrapped into the new bullet. Line count in the gotcha stayed at 5
(same as before). Used the Edit tool (not `sed`) per step 2's recorded
CRLF-stripping gotcha; `file AGENTS.md` confirms CRLF survived.

Files changed: `AGENTS.md`.

Acceptance (run from the repo root):

```
$ grep -c 'SYNCED COPY' AGENTS.md
0

$ grep -c 'claude-dual-account-setup' AGENTS.md
2

$ awk 'END{print NR}' AGENTS.md
59

$ node C:/Briar/repos/mine/Agent-Engineering/scripts/agent-lint.mjs .
agent-lint C:\Users\mateo\orca\workspaces\workstation\mat-110-claude-canonical
0 high, 0 medium, 0 low — PASS

$ file AGENTS.md
AGENTS.md: Unicode text, UTF-8 text, with CRLF line terminators
```

**Ruling on the `claude-dual-account-setup` predicate:** the PLAN's original
step-3 acceptance line asked for `grep -c 'claude-dual-account-setup'
AGENTS.md` = 1. Actual count is 2 — and was already 2 at baseline (`git
show HEAD:AGENTS.md | grep -c 'claude-dual-account-setup'` = 2, verified),
because a second, unrelated occurrence lives in the untouched "dual-account
launcher block exists in THREE synced copies" gotcha (line 32,
`accounts/skills/claude-dual-account-setup/profile-functions.ps1`) — not
part of this step's scope. Flagged to the controller before committing
rather than guessing; ruling received: the `=1` predicate was mis-specified
when the PLAN was written, and the corrected predicate is **count = 2,
unchanged from HEAD's count of 2** (proving both that this step's required
exception clause survived and that the unrelated launcher gotcha was not
collaterally edited). Both halves verified above/here. The controller is
amending PLAN.md and DECISIONS.md with this correction.

No other concerns. Committed `2c3c0dd` —
`docs(claude): flip AGENTS.md gotcha from SYNCED COPY to CANONICAL`.

#### Step 3 review — fresh reviewer, verdict verbatim

```
### Spec compliance
✅ Compliant

### Strengths
- The gotcha's factual claim was cross-checked against the files steps 1 and 2
  actually changed, not taken on faith: claude/CLAUDE.md carries the
  workstation canon comment, and both hooks carry the equivalent
  `Canonical: workstation/claude/hooks/<name> — applied to ~/.claude/hooks/ by
  claude/install.ps1.` headers. The new AGENTS.md:26-30 claim is true of the
  repo as it stands, not just internally consistent.
- The skills-junction sentence survived byte-for-byte, just reflowed.
- No collateral edit to the "THREE synced copies" launcher gotcha below
  (AGENTS.md:31-35) — confirmed identical to baseline.
- All corrected acceptance predicates pass, verified directly:
  `grep -c 'SYNCED COPY'` = 0; `grep -c 'claude-dual-account-setup'` = 2 and
  `git show HEAD:AGENTS.md | grep -c ...` = 2 — equal, per the corrected
  predicate; `awk 'END{print NR}'` = 59 (≤ 60); lint 0 high/0 medium/0 low PASS.
- Line endings: raw whole-file byte scan (`od -An -tx1`) shows all 59 line
  terminators are CRLF, including newly written lines.

### Issues
#### Critical (Must Fix)
None.
#### Important (Should Fix)
None.
#### Minor (Nice to Have)
- AGENTS.md:26 — shipped wording has a comma ("the personal machine layer,
  applied to ~/.claude...") where PLAN/SPEC phrase it without one. Meaning
  unchanged, no predicate tests exact wording; cosmetic only.

### Assessment
**Step quality:** Approved
**Reasoning:** The rewritten gotcha satisfies every corrected acceptance
predicate, states exactly what SPEC item 3 requires, and is verifiably true
against the actual post-step-1/2 state rather than just plausible-sounding.
No scope creep, no collateral edits, line budget and lint both clean.
```

Controller: the single Minor (cosmetic comma) does NOT enter the fix loop —
**deferred to work-verify's triage** per work-run's rule on Minor findings.
Step 3 closed.

### Step 4 — stamp migrated to `AE/1.4.2`, tier one-liner + `docs/tiers.md` refreshed, dispositions recorded

Three edits, all mechanical except the judgment written into `DECISIONS.md`:

1. `AGENTS.md`: `Standard: AE/1.0.0` -> `Standard: AE/1.4.2`.
2. `AGENTS.md`: the tier one-liner's `XL fan-out` -> `XL orchestrate`
   (note 1.3.0). The phrase straddled a wrap (`… · XL` / `fan-out — doubt`),
   so the two lines were rewrapped to `… four files+feature list ·` /
   `XL orchestrate — doubt → higher (docs/tiers.md).` — the phrase now lives
   on one line, which is what `grep -c 'XL orchestrate'` = 1 requires. Still
   two lines; `AGENTS.md` stays at 59.
3. `docs/tiers.md` overwritten from
   `C:/Briar/repos/mine/Agent-Engineering/templates/repo/docs/tiers.md`
   (notes 1.1.0 / 1.2.1 / 1.3.0 / 1.4.0). The template is LF; it was landed
   as CRLF (`perl -0777 -pe 's/\r\n/\n/g; s/\n/\r\n/g'`) to match the repo's
   working-tree convention. Net content change is exactly the three things
   the notes promise: the L row gains the recommended-executor mention
   (1.1.0) naming `work-run` (1.2.1), the XL row's `mandatory fan-out`
   becomes `mandatory orchestrate` (1.3.0), and the closing pointer-home
   paragraph appears (1.4.0).
4. `DECISIONS.md`: the `## Per-version migration dispositions` placeholder
   replaced with a ten-row table (1.1.0 -> 1.4.2 in numeric order — the
   notes file lists 1.4.2 before 1.4.1) plus a closing note. Everything
   above that heading — the parent's Rulings A and B with the MAT-50 link,
   and the controller's step-3 predicate correction — was left untouched;
   rows 1.3.0 and 1.3.1 cite those rulings instead of re-deciding them.

Per the step's scoping notes, `claude/install.ps1` and `tests/run.ps1` were
**not** touched — 1.3.0's installer sweep is applied by PLAN step 5 — and no
`Tracker:` line was added.

**Tooling:** used `perl -0777` (not `sed`) per step 2's recorded gotcha.
First attempt at the tier rewrap put the pattern inside `\Q…\E` with `\xNN`
escapes and matched 0 times; rewritten with the literal UTF-8 bytes in the
script it matched exactly once. Both files confirmed CRLF afterwards, and
`git diff` shows 6 changed lines in `AGENTS.md` and 9 in `docs/tiers.md` —
no whole-file line-ending churn.

**Verified for the 1.4.2 disposition (asked to check, not to take on trust):**
`agent-lint.mjs:354` is `const SHIPPED_SURFACE = /^(skills|reference|templates|global|loops)\//`,
applied at line 378 to a file list whose entries the walk (lines ~73-81)
builds as `relative(root, full).replaceAll("\\", "/")` — root-relative with
forward slashes, so the `^` anchor is the repo root. This repo has no
root-level `skills/`, `reference/`, `templates/`, `global/` or `loops/`;
`git ls-files | grep -E '(^|/)(skills|reference|templates|global|loops)/'`
returns only `accounts/skills/claude-dual-account-setup`, which starts with
`accounts/` and misses the anchor. Independent confirmation: this lane's own
`SPEC.md` and `PLAN.md` carry many `C:/Briar/...` machine paths and lint
still reports 0 findings — the check is not sweeping the whole repo.

Files changed: `AGENTS.md`, `docs/tiers.md`,
`work/mat-110-claude-canonical/DECISIONS.md`.

Acceptance (run from the repo root):

```
$ grep -c '^Standard: AE/1.4.2' AGENTS.md
1

$ grep -c 'XL orchestrate' AGENTS.md
1

$ diff --strip-trailing-cr docs/tiers.md C:/Briar/repos/mine/Agent-Engineering/templates/repo/docs/tiers.md
(empty, exit 0)

$ node C:/Briar/repos/mine/Agent-Engineering/scripts/agent-lint.mjs .
agent-lint C:\Users\mateo\orca\workspaces\workstation\mat-110-claude-canonical
0 high, 0 medium, 0 low — PASS
(exit 0)

$ file AGENTS.md docs/tiers.md
AGENTS.md:     Unicode text, UTF-8 text, with CRLF line terminators
docs/tiers.md: Unicode text, UTF-8 text, with CRLF line terminators
```

Note on the `diff` predicate: the plain `diff docs/tiers.md <template>`
reports all 30 lines as differing, purely because the working-tree copy is
CRLF and the template is LF — the "CRLF aside" the acceptance anticipates.
`diff --strip-trailing-cr` (above) and `diff <(tr -d '\r' < docs/tiers.md)
<template>` both print nothing and exit 0.

`git status --short` shows only the three intended files.

**Concern (informational, not a blocker):** `DECISIONS.md` is LF in the
working tree — matching its siblings `SPEC.md` / `PLAN.md` / `PROGRESS.md`,
which are all LF — so `git diff` prints the usual `* text=auto` "LF will be
replaced by CRLF" warning for it. Pre-existing and consistent across the
lane folder; the committed blob is LF either way. Not changed here.

Committed `<SHA>` — `docs(claude): migrate stamp to AE/1.4.2, refresh tiers.md, record dispositions`.

## Verification

<!-- Filled by work-verify at the lane gate. -->
