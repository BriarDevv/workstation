# workstation repository instructions

This repository restores a Windows 11 Pro workstation. Treat its tables and configuration
files as desired state, not as a historical inventory of the current machine.

## Execution

Use the root orchestrator unless a folder-specific run is requested:

```powershell
pwsh .\install.ps1
pwsh .\install.ps1 -WhatIfOnly
pwsh .\install.ps1 claude
```

The canonical order is defined by `$STEPS` in `install.ps1`. Read the relevant folder
README before changing its manifest or installer. `windows/debloat.ps1` is intentionally
outside the automatic restore path.

## Repository invariants

- `layout/LAYOUT.md` is the only source for custom paths. Scripts call `Get-LayoutPath`.
- README tables are complete desired lists. Do not import installed-machine snapshots.
- Keep project-specific knowledge inside that project's repository; only `dev/repos/` may
  name the repositories restored by this workstation.
- Resolve current stable versions at run time. Node uses LTS; previews require an explicit
  request. `-SkipUpgrade` must remain available.
- Every normal installer supports `-WhatIfOnly`, is safe to re-run, and returns non-zero if
  requested work failed.
- Use `_lib.ps1` for config writes. It compares first, preserves full destination paths in a
  run-scoped backup, and retains the first original copy when a file is touched twice.
- Keep secrets out of Git. Only `secrets/.env.example` belongs here; `.env`, `.claude.json`,
  keys, and certificates do not.
- The terminal ASCII `.txt` files are raw fastfetch assets. Do not reformat them.

## Claude-specific ownership

The terminal profile deliberately launches Claude with
`--dangerously-skip-permissions`; retain that behavior unless the user asks to change it.
`claude/install.ps1` preserves the live OMC-generated marker block, repairs unsupported
legacy hook shapes, and validates the merged settings with `claude doctor`.

Global Claude content must stay short and machine-wide. Generic coding advice, dated model
recommendations, usage counts, retired features, and project-specific workflow do not
belong in `claude/CLAUDE.md` or `claude/rules/common/`.

## Verification

After script changes, parse every PowerShell file and run `pwsh .\tests\run.ps1`. For a
restore-path change, also run the relevant `-WhatIfOnly` command and confirm it makes no
tracked or user-config writes. Report actual failures and remaining manual steps.

Documentation and code comments in this repo are in English, except the user-facing
`docs/post-format.md` handoff, which stays in Spanish.
