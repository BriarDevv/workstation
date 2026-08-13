# workstation

Restores a Windows 11 Pro workstation. Tables and configuration files are
desired state, not a historical inventory of the current machine.

## Commands

- `pwsh ./install.ps1` — full restore, order defined by `$STEPS` inside it
- `pwsh ./install.ps1 -WhatIfOnly` — dry run  # not verified in full here
- `pwsh ./install.ps1 claude` — one folder only
- `pwsh ./tests/run.ps1` — test suite; run after any script change

## Gotchas

- `layout/LAYOUT.md` is the only source for custom paths — scripts call
  `Get-LayoutPath`, never hardcode.
- Versions resolve at run time (Node uses LTS; previews only on explicit
  request); `-SkipUpgrade` must remain available.
- The terminal profile launches Claude with `--dangerously-skip-permissions`
  on purpose — retain unless asked otherwise.
- `claude/CLAUDE.md` is a SYNCED COPY; the canonical source is
  `Context-Engineering/global/CLAUDE.md`. Skills are junction-linked from
  the `Context-Engineering` and `skills` repos by `claude/install.ps1` —
  except `claude-dual-account-setup`, which lives in `accounts/` here and is
  linked by `accounts/install.ps1`.
- The dual-account launcher block exists in THREE synced copies:
  `accounts/skills/claude-dual-account-setup/profile-functions.ps1`
  (canonical), `terminal/powershell/profile.ps1` (what a restore writes as
  `$PROFILE`), and the live `$PROFILE`. Change a launcher in the canonical,
  run its `repair.ps1 -Force`, and mirror the terminal copy.
- `secrets/hud-accounts.json` (account emails for the HUD chip) never enters
  git; `accounts/hud-accounts.example.json` is the shape. Scheme-slot color
  names in it resolve against the active terminal scheme at install time.
- `windows/debloat.ps1` is intentionally outside the automatic restore path.
- The terminal ASCII `.txt` files are raw fastfetch assets — never reformat.
- Docs and comments in English, except the user-facing
  `docs/post-format.md` handoff, which stays in Spanish.

## Hard constraints

- Secrets never enter git: only `secrets/.env.example` ships; `.env`,
  `.claude.json`, keys, and certificates do not.
- Use `_lib.ps1` for config writes — it compares first, backs up to a
  run-scoped directory, and keeps the first original when touched twice.
- README tables are complete desired lists; never import installed-machine
  snapshots.
- Every normal installer supports `-WhatIfOnly`, is safe to re-run, and
  returns non-zero when requested work failed. After a restore-path change,
  run the relevant `-WhatIfOnly` and confirm zero tracked or user-config
  writes.
- Project-specific knowledge stays in that project's repo; only `dev/repos/`
  may name the repositories this workstation restores.
