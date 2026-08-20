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

## Verification

<!-- Filled by work-verify at the lane gate. -->
