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

## Verification

<!-- Filled by work-verify at the lane gate. -->
