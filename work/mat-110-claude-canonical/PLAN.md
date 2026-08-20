# claude/ layer becomes canonical + AE/1.0.0 -> 1.4.2 — plan

Tier M · lane `work/mat-110-claude-canonical/` · SPEC.md is the authority.

## Constraints (hold for every step)

- **Read AE, never write it.** `C:/Briar/repos/mine/Agent-Engineering` at
  merged main (`4da691f`) is the content source; nothing in that repo is
  modified. MAT-111 deletes its `global/` after this lane merges.
- **Never touch the live `~/.claude`.** Repo files only; the parent applies
  the canonical content after merge.
- **Never touch** `secrets/`, `accounts/` and the dual-account launcher's
  three synced copies, `terminal/` ASCII fastfetch assets,
  `windows/debloat.ps1`.
- **Line endings.** `.gitattributes` pins `*.ps1 text eol=crlf` and
  `* text=auto`; sync file *content*, never overwrite a CRLF working-tree
  file with AE's LF bytes.
- **Canon-comment format**, used verbatim by steps 1 and 2:
  `Canonical: workstation/claude/<path> — applied to <dest> by claude/install.ps1.`
- All artifacts in English. `main` is PR-only, rebase-only; this lane never
  merges.

## Steps

- [ ] 1. `claude/CLAUDE.md`: replace the body with AE `global/CLAUDE.md`'s
      content, then set line 3's HTML comment to
      `<!-- Canonical: workstation/claude/CLAUDE.md — applied to ~/.claude/CLAUDE.md by claude/install.ps1. -->`
      — *mechanical* — accept: `diff <(sed '3d' claude/CLAUDE.md) <(sed '3d' C:/Briar/repos/mine/Agent-Engineering/global/CLAUDE.md)` prints nothing AND
      `grep -c 'Reply in the language of each prompt' claude/CLAUDE.md` = 1 AND
      `awk 'END{print NR}' claude/CLAUDE.md` <= 40 AND
      `node C:/Briar/repos/mine/Agent-Engineering/scripts/agent-lint.mjs .` exits 0 with 0 high

- [ ] 2. `[batch]` Both hooks — `claude/hooks/orca-probe.ps1` and
      `claude/hooks/using-ae.ps1`: rewrite only the `# Canonical: …` header
      sentence to the step-1 format with dest `~/.claude/hooks/`; every other
      line, and the CRLF endings, stay byte-identical. `global/hooks/README.md`
      is NOT copied — *mechanical* — accept:
      `grep -rc 'Canonical: Agent-Engineering' claude/` = 0 AND
      `for f in orca-probe using-ae; do diff <(grep -v '^#' claude/hooks/$f.ps1 | tr -d '\r') <(grep -v '^#' C:/Briar/repos/mine/Agent-Engineering/global/hooks/$f.ps1); done` prints nothing AND
      `test ! -e claude/hooks/README.md` AND `pwsh ./tests/run.ps1` exits 0

- [ ] 3. `AGENTS.md`: rewrite the SYNCED-COPY gotcha (currently lines 26-30) so
      it states `claude/CLAUDE.md` and `claude/hooks/` are CANONICAL here — the
      personal machine layer applied to `~/.claude` by `claude/install.ps1` —
      while keeping the existing skills-junction sentence
      (`Agent-Engineering` + `skills` sources, `claude-dual-account-setup` from
      `accounts/`) intact. Stay within the 60-line target — *mechanical* —
      accept: `grep -c 'SYNCED COPY' AGENTS.md` = 0 AND
      `grep -c 'claude-dual-account-setup' AGENTS.md` = 1 AND
      `awk 'END{print NR}' AGENTS.md` <= 60 AND lint exits 0 with 0 high

- [ ] 4. Migrate the stamp. Edits the same `AGENTS.md` step 3 just rewrote, so
      it runs after it: set `Standard: AE/1.4.2`, change the tier one-liner's
      `· XL fan-out` to `· XL orchestrate` (note 1.3.0), and overwrite
      `docs/tiers.md` with `C:/Briar/repos/mine/Agent-Engineering/templates/repo/docs/tiers.md`
      (notes 1.1.0 / 1.2.1 / 1.3.0 / 1.4.0). Write `DECISIONS.md` with one row
      per version step 1.1.0 -> 1.4.2 (applied / not-applicable + why), the
      parent's two rulings, and the MAT-50 link — *judgment* — accept:
      `grep -c '^Standard: AE/1.4.2' AGENTS.md` = 1 AND
      `grep -c 'XL orchestrate' AGENTS.md` = 1 AND
      `diff docs/tiers.md C:/Briar/repos/mine/Agent-Engineering/templates/repo/docs/tiers.md` prints nothing (CRLF aside) AND
      lint exits 0 with 0 high

- [ ] 5. `claude/install.ps1`: in the skills section, after `$skillDirs` is
      built and the junctions are created, sweep **dangling only** — for each
      item under `$skillsDst` whose `LinkType` is `Junction` and whose
      `LinkTarget` no longer exists on disk, remove it; never a
      not-in-`$skillSources` purge, which would delete
      `claude-dual-account-setup` (owned by `accounts/install.ps1`). Honor
      `$script:DryRun` (`Write-Would`) and the `$failed`/`$configChanged`
      conventions already in the file. Add one guard test to `tests/run.ps1`
      in the existing `Test-Case` style asserting the sweep is
      target-existence-gated — *integration* — accept:
      `pwsh ./tests/run.ps1` exits 0 AND
      `pwsh ./install.ps1 claude -WhatIfOnly` exits 0 with zero tracked or
      user-config writes AND `git status --short` shows no change outside the
      lane and the files this PLAN names
