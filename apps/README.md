# Applications

These tables are the complete software manifest consumed by `install.ps1`. A backticked
first cell is executable data: changing a winget or npm row changes the next restore.

```powershell
pwsh apps\install.ps1
pwsh apps\install.ps1 -Optional
pwsh apps\install.ps1 -SkipUpgrade
pwsh apps\install.ps1 -WhatIfOnly
```

The installer continues after individual failures, reports them together, and exits 1 if
anything requested is missing or an update check fails. Packages already installed are
upgraded to their current stable release unless `-SkipUpgrade` is passed.

## Essentials

| winget ID | Application | Purpose |
| --- | --- | --- |
| `Git.Git` | Git | Version control |
| `GitHub.cli` | GitHub CLI | Authentication, repositories, PRs, and issues |
| `Microsoft.PowerShell` | PowerShell 7 | Runtime for this repository |
| `Microsoft.WindowsTerminal` | Windows Terminal | Interactive terminal |
| `Microsoft.VisualStudioCode` | VS Code | Editor |
| `Google.Chrome` | Chrome | Browser |
| `Docker.DockerDesktop` | Docker Desktop | Containers; may require a reboot |
| `Microsoft.WSL` | WSL 2 | Linux environment; may require a reboot |
| `Python.Python.3.14` | Python 3.14 | System interpreter for shell scripts |
| `Python.Launcher` | Python Launcher | `py` version selection and shebang support |
| `Tailscale.Tailscale` | Tailscale | Private network access |
| `RARLab.WinRAR` | WinRAR | Archives; licence activation is manual |

## Terminal

| winget ID | Application | Purpose |
| --- | --- | --- |
| `Fastfetch-cli.Fastfetch` | fastfetch | Terminal startup information |
| `DEVCOM.JetBrainsMonoNerdFont` | JetBrainsMono Nerd Font | Monospace icons and glyphs used by the style |

The font installs machine-wide and may prompt for elevation. The terminal installer resolves
the actual registered mono-family name rather than assuming a vendor naming variant.

## Desktop / utilities

| winget ID | Application | Purpose |
| --- | --- | --- |
| `CharlesMilette.TranslucentTB` | TranslucentTB | Transparent taskbar |
| `Discord.Discord` | Discord | Messaging |
| `Anthropic.Claude` | Claude Desktop | Desktop client; separate from Claude Code CLI |
| `Logitech.GHUB` | Logitech G HUB | Peripheral configuration |
| `Spotify.Spotify` | Spotify | Music |

Spotify is a per-user installer and can reject an elevated session. If that happens, finish
the elevated font install first and re-run this script unelevated; completed packages skip.

## Games

| winget ID | Application | Notes |
| --- | --- | --- |
| `Valve.Steam` | Steam | Installed into the `games` path declared in `layout/LAYOUT.md` |
| `RiotGames.LeagueOfLegends.LA2` | League of Legends | LA2/LAS package; its installer asks for the declared game path |

The Riot client is bundled with League and does not need a separate manifest row.

## Runtimes

| winget ID | Runtime |
| --- | --- |
| `Microsoft.DirectX` | Legacy DirectX redistributable |
| `Microsoft.VCRedist.2005.x86` | Visual C++ 2005 x86 |
| `Microsoft.VCRedist.2005.x64` | Visual C++ 2005 x64 |
| `Microsoft.VCRedist.2008.x86` | Visual C++ 2008 x86 |
| `Microsoft.VCRedist.2008.x64` | Visual C++ 2008 x64 |
| `Microsoft.VCRedist.2010.x86` | Visual C++ 2010 x86 |
| `Microsoft.VCRedist.2010.x64` | Visual C++ 2010 x64 |
| `Microsoft.VCRedist.2012.x86` | Visual C++ 2012 x86 |
| `Microsoft.VCRedist.2012.x64` | Visual C++ 2012 x64 |
| `Microsoft.VCRedist.2013.x86` | Visual C++ 2013 x86 |
| `Microsoft.VCRedist.2013.x64` | Visual C++ 2013 x64 |
| `Microsoft.VCRedist.2015+.x86` | Visual C++ 2015–2022 x86 |
| `Microsoft.VCRedist.2015+.x64` | Visual C++ 2015–2022 x64 |

Both architectures are intentional; an x64 runtime does not satisfy a 32-bit application.

## Optional

Only installed with `-Optional`.

| winget ID | Application | Reason it is optional |
| --- | --- | --- |
| `Ollama.Ollama` | Ollama | Local models require significant disk space |

## Microsoft Store

These rows use `--source msstore`; a signed-in Microsoft account may be required.

| winget ID | Application | Reason |
| --- | --- | --- |
| `XP8CLZL93F5Z4P` | NVIDIA App | Store is the selected automated distribution source |

## Manual afterwards

| What | Why it remains manual | Source/action |
| --- | --- | --- |
| **Porofessor** | Vendor installation is not part of this manifest | `porofessor.gg` |
| **Wallpaper Engine** | Purchased and installed through Steam | Steam library |
| **Pencil** | Desktop app owns its updates and Claude MCP registration | `pencil.dev` |
| **WinRAR licence** | Requires the user's licence key | Enter after installation |
| **`gh auth login`** | Interactive OAuth | Run before cloning the private repo |
| **League install path** | Riot's installer prompts interactively | Choose the LA2 path in `layout/LAYOUT.md` |

## Language tooling

Node is installed from the official current LTS ZIP into the `node` path declared by
`layout/LAYOUT.md`. The script stages extraction before replacing an existing runtime.
`pnpm` is activated through Corepack and `uv` uses its official installer/self-updater.

The literal Node version in the script is only an offline fallback. The Python major in the
winget ID is explicit desired state; moving to a new major requires changing the row.

## npm globals

| Package | Purpose |
| --- | --- |
| `oh-my-claude-sisyphus` | OMC orchestration layer for Claude Code |

Global executables land in `%APPDATA%\npm`, which the installer adds to the user PATH. The
repo-owned `.npmrc` sets `ignore-scripts=true`; override it only for a specific trusted
package that genuinely requires an install script.

Use `snapshot.ps1` to compare npm globals in both directions. Winget drift is intentionally
checked only for declared IDs because Windows itself contributes many unrelated packages.
