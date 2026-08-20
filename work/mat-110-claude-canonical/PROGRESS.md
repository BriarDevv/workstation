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

## Verification

<!-- Filled by work-verify at the lane gate. -->
