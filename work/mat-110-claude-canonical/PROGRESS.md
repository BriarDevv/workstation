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

Committed `6a7e12a` — `docs(claude): migrate stamp to AE/1.4.2, refresh tiers.md, record dispositions`.

**Commit-message history for that commit (content never changed — same tree
`682652a` throughout, verified with `git rev-parse HEAD^{tree}` before and
after each amend):**

1. `83db313` — created with a mangled message: a PowerShell here-string
   quoting form (`-m @'…'@`) leaked into a Bash call, so the subject became
   `@` and the body was truncated mid-sentence. Caught immediately.
2. `3b16f04` — message rewritten with `git commit --amend -F <file>`
   (local, unpushed, seconds old). Clean conventional subject, complete body.
3. `6a7e12a` — **final.** The controller reviewed the mangled `83db313` and
   asked for the amend plus a `Refs MAT-110` trailer, which the branch's
   other commits carry and `3b16f04` did not. Amended again, message-only:
   the SHA-record commit was soft-reset and unstaged first so the index
   equalled HEAD and the amend could not pick up file changes. The body now
   also states the stamp transition explicitly (`AE/1.0.0` -> `AE/1.4.2`).
   Verified with `git log -1 --format='%s%n%b'`.

#### Step 4 review — fresh reviewer (capable tier), verdict verbatim

```
### Spec compliance
✅ Compliant — all four acceptance predicates pass, both pre-rulings honored, no
collateral damage. Nothing Missing, Extra, or Misunderstood. No ⚠️ items.

- `grep -c '^Standard: AE/1.4.2' AGENTS.md` → 1 (AGENTS.md:3)
- `grep -c 'XL orchestrate' AGENTS.md` → 1 (AGENTS.md:9)
- tiers.md vs template → empty diff CRLF-aside; `cat -A` shows `^M$` on all 30
  lines; em dashes/arrows survived as UTF-8.
- lint → `0 high, 0 medium, 0 low — PASS`, exit 0.

(a) Ten rows, 1.1.0 → 1.4.2, none skipped; the out-of-order 1.4.2/1.4.1 trap is
named, not just avoided. (b) Each note read against its row: all six
not-applicable rows sit on notes whose own text says restamp-only or whose
obligation is provably inert; all four applied claims are present in the diff.
(c) 1.3.0 recorded as applied-in-two-parts with part (b) implemented by PLAN
step 5 (installer and tests deliberately untouched, `Closes MAT-50`); 1.3.1
recorded as skipped citing Ruling B. `grep -c '^Tracker' AGENTS.md` → 0.
(d) tiers.md carries all three named items (L-row executor mention, XL
`mandatory orchestrate`, closing pointer-home paragraph). (e) AGENTS.md = 59
lines, inside the 60 target; no line over 79 chars, so the re-wrap did not trade
lines for width. (f) Two hunks in one 12-line window; all three earlier
DECISIONS.md sections intact.

### Strengths
- The two rows with the most room to be lazy are the two verified hardest.
  1.2.0's note says "the hook applies via the workstation installer" — exactly
  the sentence that stops being safe when THIS repo is that installer. The row
  noticed and checked; each leg confirmed independently.
- 1.4.2 was verified in the check's source, not taken from the note, and the
  quoted mechanism is exactly right (SHIPPED_SURFACE at :354, filter at :378,
  paths built root-relative at :76 — so `^` really is repo-root-anchored).
- 1.4.0's optional adoptions each checked, not waved off.
- The re-wrap satisfies the predicate honestly — `XL orchestrate` reads as one
  phrase, not gaming the grep.

### Issues
#### Critical (Must Fix)
None.
#### Important (Should Fix)
None.
#### Minor (Nice to Have)
1. DECISIONS.md:85 — the quoted SHIPPED_SURFACE regex escapes its pipes for the
   markdown table (`\|`), which renders right but reads as a literal pipe in raw
   JS-regex terms. The argument rests on the `^` anchor, so nothing downstream is
   wrong. Fix: note "(pipes escaped for the table)" or restate as prose.
2. DECISIONS.md:83 and :85 — the two longest cells are 645 and 914 chars. Every
   clause is load-bearing, so not padding, but hard to scan raw.
3. DECISIONS.md:84 — 1.4.1's row disposes of the two optional pickups but never
   mentions the two new lint checks that release added. Nothing is owed (lint is
   clean); a half-clause would close the loop.

### Assessment
**Step quality:** Approved
**Reasoning:** All ten version steps are dispositioned, each disposition matches
what its migration note actually demands, and every evidence claim spot-checked
against the repo and against agent-lint.mjs held exactly as written — including
the two rows (1.2.0, 1.4.2) where "restamp only" would have been the easy and
wrong answer. The mechanical half passes all four predicates with the 59-line
budget intact and zero collateral edits.
```

Controller: three Minors, none entering the fix loop — **deferred to
work-verify's triage** per work-run's rule. Separately, the controller sent step
4's commit back once before review: commit `83db313` carried a malformed message
(stray `@ ` subject prefix, body truncated mid-sentence). No file content
changed; amended to `3b16f04` with a complete conventional message, verified with
`git log -1 --format='%s%n%b'`. Step 4 closed.

### Step 5 — dangling-only skill junction sweep in `claude/install.ps1` + guard test

Added a 25-line sweep to `claude/install.ps1`'s skills section, immediately
after the junction-creation loop (so a skill that merely *moved* between
sources is repointed first and never sees the sweep), before the
`settings.json` section. It mirrors the rules-cleanup precedent 50 lines
above it (`claude/install.ps1:208-224`) beat for beat — `Get-ChildItem …
-ErrorAction SilentlyContinue`, `continue` guards, `Write-Would` under
`$script:DryRun`, `try { … $configChanged = $true; Write-Ok } catch {
Write-Fail; $failed.Add(…) }` — rather than inventing a shape.

The gate, in order: skip anything whose `LinkType` is not `Junction` (a real
directory or a plugin's own folder is never this script's to remove), then
skip when `LinkTarget` is empty **or** still resolves on disk. Only a
junction whose target is gone reaches `Remove-Item`. `$skillDirs` and
`$skillSources` are deliberately not consulted anywhere in the block — the
negative assertion in the guard test enforces exactly that.

`-Recurse -Force` on the removal matches the existing junction replacement at
`claude/install.ps1:269`; PS7 (asserted by `Assert-PowerShell7`) removes the
link, not the target's contents, and a dangling junction has no reachable
contents at all. Without `-Recurse`, a directory-type item risks an
interactive confirmation prompt, which would hang a non-interactive restore.

**On the backup question (asked for explicitly): no backup, deliberately.**
Two independent reasons. (1) A junction stores a path, not content, and a
*dangling* junction's target is already gone — there is nothing to copy;
recreating it needs only the name and the target string, both of which the
removal line prints. (2) `Backup-ExistingFile` is leaf-gated
(`_lib.ps1:71`: `if (-not (Test-Path -LiteralPath $Destination -PathType
Leaf)) { return $null }`), so it returns `$null` for *any* junction —
calling it here would be a guaranteed no-op that reads to a future maintainer
as if a backup happened. Note this also means the existing
`Backup-ExistingFile $link` on the replacement path (`install.ps1:268`) is
itself a no-op for junctions; that is pre-existing and out of this step's
scope, so it was left alone. The `_lib.ps1` constraint is not bypassed —
it governs *config writes*, and no file content is written or destroyed here.

Guard test `skill junction sweep is gated on a missing target, never on the
source list` added to `tests/run.ps1` next to the existing
`claude hooks are declared, shipped, and merged safely` test (the other test
that inspects `claude\install.ps1`). Two halves:

- **Source half (the real guard).** Extracts just the sweep block by regex
  (`foreach ($live in @(Get-ChildItem $skillsDst … \n}`) so the negative
  assertion is block-scoped — `$skillDirs` appears elsewhere in the file
  legitimately — then asserts: junction-confined, `$target =
  $live.LinkTarget` + `Test-Path -LiteralPath $target` present, `$skillDirs`
  / `$skillSources` **absent**, dry run honored, `$failed.Add` present.
- **Behavioral half.** Builds a temp sandbox with three real entries — a live
  junction, a dangling junction (target created, junction made, target
  deleted) and a plain directory — and asserts the `LinkType` + `LinkTarget`
  + `Test-Path` triple selects exactly one of them, `dangling`. Junctions
  need no elevation, and cleanup is temp-prefix guarded like the existing
  `$testRoot` block.

**Mutation-checked so the guard is not vacuous** (run against in-memory
copies of the source; the repo file was never modified):

```
as shipped                            -> PASS
mutation: not-in-sources purge        -> FAIL: target-gated, no-name-purge
mutation: no gate at all              -> FAIL: target-gated
mutation: junction confinement dropped-> FAIL: junction-only
mutation: dry run ignored             -> FAIL: dry-run
```

Files changed: `claude/install.ps1`, `tests/run.ps1`.

Acceptance (run from the repo root):

```
$ pwsh ./tests/run.ps1
  [ok]   skill junction sweep is gated on a missing target, never on the source list
=== Result
  27 passed, 0 failed
EXIT=0

$ pwsh ./install.ps1 claude -WhatIfOnly
=== Skills (repo junctions)
  [ok]   ae-audit junction already in place
  … (15 in-place junctions) …
  would  remove dangling skill junction reviewing-plans -> C:\Briar\repos\mine\skills\skills\reviewing-plans
=== Summary
  [ok]   nothing failed
  Dry run complete; no Claude files changed.
EXIT=0

$ git status --short
 M claude/install.ps1
 M tests/run.ps1
```

Zero user-config writes, proven rather than asserted: a hash snapshot of
`~/.claude/CLAUDE.md`, `settings.json`, `hooks/`, `rules/`, `~/.claude.json`
plus the name/LinkType/LinkTarget of every entry under `~/.claude/skills`
(29 rows) was taken before and after the dry run and `diff`s identical, and
`~/.workstation-backup`'s newest run directory is still yesterday's
(`2026-08-19_042912957-34280`) — the dry run created none. The `would
overwrite CLAUDE.md / hooks / settings.json` lines in the output are
pre-existing reports of steps 1-2's content, not writes.

`pwsh ./tests/run.ps1` still prints the pre-existing `[!] Workstation.Test.Package
update check failed (winget exit 37)` line; that is the winget-availability
condition PROGRESS already records, and the suite exits 0.

**Live-machine finding worth the parent's attention (not a defect in this
step).** The sweep is not hypothetical here: `~/.claude/skills/reviewing-plans`
is a **real dangling junction on this machine right now**, pointing at
`C:\Briar\repos\mine\skills\skills\reviewing-plans`, which no longer exists —
and neither does a `reviewing-plans` directory in *either* declared source
(`Agent-Engineering\skills`, `skills\skills`) or in `~/.agents/skills`. It is
exactly the MAT-50 scenario. Consequence: the first real (non-dry-run)
`install.ps1 claude` after this merges will delete that junction. That is the
intended fix, but it is a live-machine change, so it should not arrive as a
surprise — if `reviewing-plans` is still wanted, its source needs restoring in
one of the two skill repos first. DECISIONS.md's Ruling A notes the machine had
no dangling *`fan-out`* junction; it does have this one.

Safety rule verified against live state, not just the test: the dry run
printed **no** sweep line for `claude-dual-account-setup` (junction ->
`C:\Briar\repos\mine\workstation\accounts\skills\claude-dual-account-setup`,
target live) even though that name is absent from `$skillSources`, nor for
the five Orca-owned `~/.agents/skills` junctions (`computer-use`,
`find-skills`, `orca-cli`, `orca-linear`, `orchestration`), which are equally
not-in-sources. A name-based purge would have listed all six.

Line endings: both files are UTF-8/ASCII CRLF and stayed that way —
`perl -ne 'print unless /\r\n$/'` reports no LF-only line in either
(607/607 and 517/517), and `git diff --stat` shows 25 and 43 pure insertions
with no whole-file churn. Edits made with the Edit tool, not `sed`, per
step 2's recorded gotcha.

No concerns.

#### Step 5 fix round 1 — the guard test now executes the shipped sweep

Reviewer finding (Important, `tests/run.ps1` only): the guard did not guard. Two
mutations of the gate at `claude/install.ps1:288` passed it — inverting the
`Test-Path` and dropping the gate while still naming `Test-Path` — because the
assertions checked those strings were *present*, not how they were used, and the
sandbox half exercised a predicate re-written inside the test, which no change to
the installer can falsify. Finding accepted in full; my original mutation check
was not evidence for the property it claimed, since every mutation I chose
happened to delete one of the presence-checked strings.

`claude/install.ps1` is unchanged — `git diff HEAD -- claude/install.ps1` is empty
against `67ae603`.

**Variant chosen: execute the extracted block (`Invoke-Expression $body`).** The
`_lib.ps1` `Get-DanglingJunction` helper variant is the cleaner shape in the
abstract, but it requires editing `claude/install.ps1` to call the helper, and the
installer is approved and explicitly frozen this round. Between a test that runs
the shipped bytes and one that runs a helper the shipped code merely calls, the
first is also the stronger guarantee here: the property under test is a property
of that specific block.

What replaced the sandbox half (`tests/run.ps1:406-433`): the same three real
entries (live junction, dangling junction, plain directory) are now handed to the
extracted block itself. `$skillsDst` points at the sandbox, `Write-Would` /
`Write-Ok` / `Write-Fail` are shadowed by silent local stubs so the sweep's output
stays out of the suite's, and `$failed` / `$configChanged` stand in for the
installer's. The block runs twice: once with `$script:DryRun = $true`, asserting
all three entries survive and `$configChanged` stays false; then with `$false`,
asserting the survivors are exactly `live, plain` and that the run reported one
clean change. `$script:DryRun` is saved and restored in the `finally`. All the
source assertions are kept, including the `$skillDirs|$skillSources` absence check
— no execution test replaces that one.

**Mutation evidence.** Harness: copy the whole repo (minus `.git`) to
`%TEMP%\sweep-mutation-<pid>`, mutate `claude/install.ps1` **in the copy**, run the
copy's `tests\run.ps1`, read this test's result line, delete the copy. The repo
file is never written; the harness asserts the mutation actually applied before
trusting a FAIL:

```
baseline (unmutated copy)                                            -> PASS (not caught)
M1 gate inverted (keeps dangling, deletes live)                      -> FAIL (caught)
      sweep left: dangling, plain
M2 gate dropped, Test-Path still mentioned (deletes every junction)  -> FAIL (caught)
      sweep left: plain
M3 junction confinement inverted (sweeps real directories)           -> FAIL (caught)
      sweep does not confine itself to junctions
M4 dry run ignored                                                   -> FAIL (caught)
      sweep does not honor dry run
M5 not-in-sources purge (deletes claude-dual-account-setup)          -> FAIL (caught)
      sweep removal is not gated on the junction target being gone
```

M1 and M2 — the two the reviewer proved slipped through — now fail on the
*behavioral* assertion (`sweep left: …`), not on a string match. M3 and M4 trip a
source assertion first, and would be caught behaviorally too if it were removed
(the inverted confinement removes nothing, leaving three survivors; the ignored
dry run leaves two where three are required). M5 is caught by the `$skillDirs`
absence check the reviewer asked to keep.

After the harness: `git status --short` shows only `tests/run.ps1`, and
`git diff HEAD -- claude/install.ps1` is empty — the installer is byte-identical
to the approved commit.

```
$ pwsh ./tests/run.ps1
  [ok]   skill junction sweep is gated on a missing target, never on the source list
=== Result
  27 passed, 0 failed
EXIT=0
```

`tests/run.ps1` stays ASCII/CRLF (541 lines, no LF-only line).

Not acted on, per the controller: the three findings about the sweep removing
dangling junctions owned by other installers, and the unreachable-target and
missing-source cases. They are consequences of Ruling A as written and are with
the parent as a ruling question. *(Superseded within the same round — see the
addendum below; the parent approved both narrowings and they are implemented.)*

#### Step 5 fix round 1, addendum — Ruling A's two narrowings implemented

The controller's addendum superseded the "do not change `claude/install.ps1`"
freeze: the parent approved both narrowings recorded in DECISIONS.md
(`363d5d9`). Both are now in the installer, and the guard test pins both.

**(1) `$skillSources` prefix narrowing.** Removal now takes two conditions, not
one: the target is gone AND the target sits under a declared `$skillSources`
root. Implemented as a prefix test on the *path*, not a name lookup — the roots
are normalized once per run with `[IO.Path]::GetFullPath($_).TrimEnd('\') + '\'`
and matched with `StartsWith(..., OrdinalIgnoreCase)`. The appended separator is
the part that carries the `skills-other` requirement: without it,
`…\skills-other\x` matches the root `…\skills`; with it, it cannot. Case
insensitivity is required on Windows and `GetFullPath` normalizes `..` segments
and trailing slashes, so a root written any of the usual ways compares the same.
MAT-50's motivating case still sweeps: a renamed skill leaves a junction at
`<source>\<oldname>`, which is under a declared root.

The accepted cost is recorded in the code comment as the ruling requires — rename
a source *repo* and its junctions stop being swept, because their dead targets no
longer sit under any declared root.

**(2) Missing-source skip.** `$sourcesComplete` starts `$true` and is cleared in
the existing `Write-Warn2 "skills source not found…"` branch. The sweep is
wrapped in `if (-not $sourcesComplete) { Write-Warn2 … } else { … }`, so a run
that could not read a declared source sweeps nothing and says why:
`dangling junction sweep skipped - a declared skills source is missing, so every
junction into it would read as dangling`. The unreachable-target caveat the
parent asked for is documented in the same comment block: `Test-Path` answers
`$false`, not an error, for a disconnected mapped drive or a parent that lost
traverse permission, so a merely unreachable target reads as gone — this skip is
what keeps that from becoming a mass deletion.

`reviewing-plans` is not special-cased: its target
`C:\Briar\repos\mine\skills\skills\reviewing-plans` sits under the declared root
`…\mine\skills\skills`, so the narrowed sweep still reports exactly it.

**Guard test extended.** The extraction now captures the whole
`if (-not $sourcesComplete) … else { … }` construct, so executing `$body`
exercises the suppression too. The sandbox grew from three entries to five, and
runs the block three times:

| Entry | What it is | Expected |
|---|---|---|
| `live` | junction into the declared source, target alive | survives |
| `dangling` | junction into the declared source, target gone | swept |
| `sibling` | target gone under `…\skills-other` — a name that merely starts like the declared root `…\skills` | **survives** |
| `foreign` | target gone outside every declared root; stands in for `claude-dual-account-setup` and the `~\.agents\skills` links | **survives** |
| `plain` | a real directory, not a junction | survives |

Runs: dry run with sources complete (all five survive, no change reported);
`$sourcesComplete = $false` outside dry run (all five survive — the suppression);
then sources complete outside dry run (survivors exactly `foreign, live, plain,
sibling`, one clean change, no failures). One source assertion was added for the
half the sandbox cannot see: the sandbox sets `$sourcesComplete` itself, so only
the source text can show that a *missing source* is what clears it.

**Mutation evidence** (same harness: whole repo copied to
`%TEMP%\sweep-mutation-<pid>`, mutated in the copy, the copy's suite run, repo
file never written; each mutation is asserted to have applied before a FAIL is
trusted):

```
baseline (unmutated copy)                                            -> PASS (not caught)
M1 target gate inverted (keeps dangling, deletes live)               -> FAIL  sweep left: dangling, foreign, plain, sibling
M2 target gate dropped, Test-Path still named                        -> FAIL  sweep left: foreign, plain, sibling
M3 junction confinement inverted (sweeps real directories)           -> FAIL  sweep does not confine itself to junctions
M4 dry run ignored                                                   -> FAIL  sweep does not honor dry run
M5 not-in-sources name purge (deletes claude-dual-account-setup)     -> FAIL  sweep removal is not gated on the junction target being gone
M6 source-root prefix test dropped (sweeps foreign dangling links)   -> FAIL  sweep left: live, plain
M7 root prefix loses its trailing separator (skills-other matches)   -> FAIL  sweep left: foreign, live, plain
M8 missing-source guard removed (if/else collapsed to the sweep)     -> FAIL  claude\install.ps1 has no dangling skill junction sweep
M9 missing source no longer clears $sourcesComplete                  -> FAIL  a missing skills source does not clear $sourcesComplete, so the sweep would still run
```

The two the addendum asked for specifically: **M6** deletes `foreign` and
`sibling` — the foreign-link protection — and **M7** deletes `sibling` alone,
which is the `skills-other` case; both fail on survivors, not on a string match.
Two honest notes on how the last two are caught: **M8** is caught *structurally*,
by the extraction anchor rather than by behavior — collapsing the guard leaves no
`if (-not $sourcesComplete)` to extract, so the test fails with "has no dangling
skill junction sweep"; the behavioral half covers the same property from the
other side (scenario 2 proves a cleared flag really suppresses). **M9** is caught
by the new source assertion, which is the only thing that can see it.

Acceptance re-run after both narrowings:

```
$ pwsh ./tests/run.ps1
  [ok]   skill junction sweep needs a dead target under a declared source root
=== Result
  27 passed, 0 failed
EXIT=0

$ pwsh ./install.ps1 claude -WhatIfOnly
=== Skills (repo junctions)
  … 15 in-place junctions …
  would  remove dangling skill junction reviewing-plans -> C:\Briar\repos\mine\skills\skills\reviewing-plans
EXIT=0

$ git status --short
 M claude/install.ps1
 M tests/run.ps1
```

Same single `reviewing-plans` removal as before the narrowing, and zero writes on
the same evidence as the first run: the 29-row before/after snapshot of
`~/.claude` diffs identical and `~/.workstation-backup`'s newest run directory is
still `2026-08-19_042912957-34280`. Both files stay CRLF (`claude/install.ps1`
UTF-8, `tests/run.ps1` ASCII; no LF-only line in either).

No concerns.

#### Step 5 review — fresh reviewer (capable tier), verdict verbatim

```
### Spec compliance
❌ Issues found — the installer change is fully compliant; the guard test is not.

Code (claude/install.ps1) — compliant. Sweep sits after $skillDirs is built and
after the creation loop; gated on LinkType -eq 'Junction' plus a non-existent
LinkTarget; no reference to $skillDirs/$skillSources; honors $script:DryRun via
Write-Would; feeds $failed on error and $configChanged on success.

Test (tests/run.ps1) — misunderstood. The test asserts that certain TEXT appears
in the sweep block, and that PowerShell's primitives discriminate — on a
predicate the test re-implements itself. Neither half asserts the installer's
gate. Proven by mutation: two mutations of the gate — one inverting it, one
dropping it — both PASS the new test.

Acceptance commands — all pass: tests 27 passed/0 failed exit 0; -WhatIfOnly
exit 0, printed "would remove dangling skill junction reviewing-plans"; zero
writes (~/.claude/skills still 22 entries); git status empty.

### Strengths
- The gate is genuinely target-only and holds under every edge case traced:
  non-junction kept; LinkTarget null/empty kept (fail-safe); relative targets
  unreachable (Windows junctions store absolute paths); Test-Path does not throw
  on missing drive, invalid chars, empty string or 300-char path.
- Blast radius is a link, never content — Remove-Item on a junction deletes only
  the reparse point.
- claude-dual-account-setup survives — verified on the live machine, not argued.
  The dry run listed exactly one removal and left it and five Orca-owned
  ~/.agents/skills junctions untouched. Those six are live proof of why Ruling
  A's "never a not-in-sources purge" matters.
- Failure conventions match exactly; comment block's backup claim checked
  against _lib.ps1 source and is true, not hand-waved.

### Issues
#### Critical (Must Fix)
None.
#### Important (Should Fix)
1. tests/run.ps1 — the guard test does not guard (mutation table above).
2. The sweep can remove dangling junctions owned by other installers — faithful
   to Ruling A, flagged because the live machine has six. Parent's call.
3. A temporarily unreachable target reads as "gone"; a missing source repo makes
   the sweep remove every junction from that source. Parent's call.
#### Minor (Nice to Have)
Extraction regex welded to source text; test placement; positional
Get-ChildItem; symlink wording.

### Assessment
**Step quality:** Needs fixes
**Reasoning:** The installer change is correct, idiomatic and safe — every edge
case traced and confirmed on the live machine. The defect is in the deliverable's
other half: mutation testing shows the guard test passes with the gate inverted
AND removed entirely, so it does not prove the property the step was created to
protect.
```

#### Step 5 fix round 1 — scoped re-review, verdict verbatim

Findings 2 and 3 were escalated to the parent (they narrow Ruling A) and both
were APPROVED, so round 1 covered all three.

```
### Finding verdicts
Finding 1 — the guard test does not guard. ADDRESSED. The test now extracts the
shipped block and executes it with Invoke-Expression rather than re-implementing
the predicate. Independently mutation-tested: inverting the Test-Path gate and
dropping it entirely both now make the test FAIL, closing the exact hole.

Finding 2 — $skillSources prefix narrowing. ADDRESSED. $sourceRoots built via
GetFullPath().TrimEnd('') + '', gated with StartsWith(OrdinalIgnoreCase) — a
prefix test, not a name lookup. The trailing separator correctly stops
...\skills-other from matching ...\skills\.

Finding 3 — skip the sweep when any declared source is missing. ADDRESSED.
$sourcesComplete cleared in the missing-source branch; the whole sweep is skipped
with a logged reason. The unreachable-target caveat is documented in the comment
block exactly where required.

### Mutation testing (independent, scratch copy)
Copied the full repo to scratch (checkout never touched), baseline 27 passed:
1. Invert the Test-Path gate → test FAILS ("sweep left: dangling, foreign, plain,
   sibling").
2. Drop the prefix condition → test FAILS ("sweep left: live, plain") — this is
   the claude-dual-account-setup-deletion mutation, now caught.
3. Remove the missing-source suppression → test FAILS at the static assertion.
git status --short on the real checkout empty before and after.

Also ran the real repo: tests 27 passed/0 failed; -WhatIfOnly printed "would
remove dangling skill junction reviewing-plans -> C:\Briarepos\mine\skillsskillseviewing-plans" (a real dangling junction under a declared source root)
while leaving every live junction and claude-dual-account-setup alone, ending
"Dry run complete; no Claude files changed."

### New breakage in the fix diff
Minor — unguarded [IO.Path]::GetFullPath($target), outside the try/catch. Any
throw would abort the whole run. Very low risk: $target is only reached after
Test-Path parsed it without throwing, and every junction target here is created
by this installer, accounts/install.ps1 or Orca under the same constraints. Could
not construct a realistic target that passes Test-Path yet makes GetFullPath
throw. Fail-loud, not fail-silent. Not blocking.

$sourcesComplete interaction with $failed: correct — a missing source still calls
$failed.Add(...) independently, so the run still exits non-zero for that reason;
the sweep-skip is orthogonal and masks nothing.

### Out-of-scope observations
None.

### Verdict
**Fix round:** All findings addressed, no new Critical/Important breakage.
```

Controller: fix round 1 closed at round 1 of 5. The one new Minor (unguarded
`GetFullPath`) is **deferred to work-verify's triage**. Step 5 closed.

## Verification

<!-- Filled by work-verify at the lane gate. -->
