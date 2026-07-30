# workstation

PowerShell scripts and manifests that restore a Windows 11 Pro workstation.
Desired state, not inventory.

Core commands:
- `pwsh ./install.ps1 -WhatIfOnly` (dry run) / `pwsh ./tests/run.ps1` (tests)

Claude Code is the primary tool for this repo; the maintained context file is
`CLAUDE.md`. This file exists as a minimal entry point for other AI tools.
