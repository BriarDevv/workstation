# workstation

Desired state for one Windows 11 Pro development workstation. The repository restores the
machine from a clean install and keeps the decisions that must be reproducible: filesystem
layout, applications, terminal, development tools, Claude Code, and Windows preferences.

It is a manifest, not a snapshot. Installed software or old experiments do not become
desired merely because they still exist on the current machine.

## Fresh install

For the shortest human bootstrap and a ready-to-paste Claude Code handoff, follow
[`docs/post-format.md`](docs/post-format.md).

For a manual restore instead of the Claude handoff, install the same four prerequisites from
Windows PowerShell, open a new PowerShell 7 window, authenticate, and continue:

```powershell
winget install --id Git.Git --exact
winget install --id Microsoft.PowerShell --exact
winget install --id GitHub.cli --exact
irm https://claude.ai/install.ps1 | iex

gh auth login
git clone https://github.com/BriarDevv/workstation.git $HOME\workstation
cd $HOME\workstation
pwsh .\install.ps1 -WhatIfOnly
pwsh .\install.ps1
```

GitHub authentication is required regardless of this repository's visibility: `dev/`
restores other repositories under the same `gh`-backed credential helper. Claude login is
completed by launching `claude`. If a fresh Windows installation does not expose `winget`,
follow the App Installer fallback in `windows/README.md`.

## Restore order

The root installer is the executable source of truth:

1. `layout/` creates the declared filesystem tree.
2. `apps/` installs binaries and language tooling.
3. `terminal/` composes Windows Terminal, fastfetch, and the PowerShell profile.
4. `dev/` applies Git configuration and restores repositories.
5. `claude/` applies Claude Code configuration and optional MCP servers.
6. `accounts/` applies the dual Claude account system: ambient default, links,
   launcher functions, and the HUD account mapping.
7. `windows/` applies OS preferences and restarts Explorer when necessary.

Useful forms:

```powershell
pwsh .\install.ps1                    # full restore
pwsh .\install.ps1 -WhatIfOnly        # full read-only preview
pwsh .\install.ps1 claude             # selected folder
pwsh .\install.ps1 layout apps dev    # selected folders, canonical order
pwsh .\install.ps1 -Secrets           # include Claude user-scope MCP sync
```

Docker, WSL, drivers, or Windows Update may leave a reboot pending. After `apps/`, the
orchestrator checks Windows' reboot signals and stops cleanly if a restart is required.
The final Windows step applies user settings unelevated but returns 1 while machine-wide
settings remain; complete those with the elevated command printed by the script.

## Folder boundaries

| Folder | Owns |
| --- | --- |
| `layout/` | Paths and permissions under the workstation root |
| `apps/` | Desired winget packages, Node LTS, pnpm, uv, and npm globals |
| `terminal/` | Terminal style and generated user configuration |
| `dev/` | Git defaults and repository manifests |
| `claude/` | Claude instructions, settings, plugins, skills policy, and MCP manifest |
| `windows/` | Bootstrap fallback, before/after audit, privacy/UI settings, debloat, and USB notes |
| `secrets/` | Variable names only; real values remain ignored |

Every folder explains its own manual work. `apps/README.md` is the package manifest;
`layout/LAYOUT.md` is the only source for custom paths.

## Safety and failure behavior

- Installers are idempotent and return a non-zero exit code when requested work fails.
- `-WhatIfOnly` reaches every normal restore folder, including `terminal/`.
- Files replaced outside the repo are backed up under
  `~/.workstation-backup/<timestamp>-<pid>/`, preserving their full original path.
- A file is backed up only once per run, so later writes cannot replace the original copy.
- `snapshot.ps1` is read-only and reports drift; it never turns the current machine into the
  desired manifest automatically.
- `windows/debloat.ps1` remains a separate, explicit command because it removes packages.

## Versions

Installers resolve the current stable release at run time and upgrade declared packages.
Node follows the current LTS line. `-SkipUpgrade` is the deliberate offline/pinning escape
hatch for a run. A version embedded in a winget package ID, such as a Python major, changes
only when that manifest row is edited.

## Secrets

The repo contains no live credentials. Copy `secrets/.env.example` to `secrets/.env`, fill
it locally, and pass `-Secrets`. Claude MCP servers are applied through `claude mcp` at user
scope and stored by Claude Code in `~/.claude.json`; that file remains outside the repo.

## Maintenance

```powershell
pwsh .\snapshot.ps1
pwsh .\tests\run.ps1
```

Review each reported difference. Add it to the desired manifest only if it should return
after the next format; otherwise remove it from the machine.

The checklist that is relevant only immediately before erasing the machine lives separately
in [`docs/pre-format.md`](docs/pre-format.md).
