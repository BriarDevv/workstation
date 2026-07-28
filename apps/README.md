# Apps

Which programs I have and **why**. The "what for" column is the important one — in eight
months you won't remember what Radmin VPN was doing here.

`install.ps1` reads the winget IDs out of the tables below (the ones in `backticks` in the
first column). Add a row and it gets installed on the next run.

---

## Essentials

Nothing works without these. All of them get installed.

| winget ID                    | What it is       | What I use it for                                            |
| ---------------------------- | ---------------- | ------------------------------------------------------------ |
| `Git.Git`                    | Git              | Obvious. Note: mine lives in `C:\Briar\Code\Git`, not Program Files |
| `GitHub.cli`                 | `gh`             | PRs, issues and cloning without opening a browser. Account `BriarDevv` |
| `Microsoft.PowerShell`       | PowerShell 7     | This repo's scripts use `&&` and `??`, which PS5 doesn't have |
| `Microsoft.WindowsTerminal`  | Windows Terminal | Daily driver                                                  |
| `Microsoft.VisualStudioCode` | VS Code          | Main editor                                                   |
| `Docker.DockerDesktop`       | Docker           | Containers. **Requires a reboot**                             |
| `Microsoft.WSL`              | WSL2             | Linux for whatever doesn't run on Windows. **Requires a reboot** |
| `Python.Python.3.14`         | Python 3.14      | The main one                                                  |
| `Python.Launcher`            | `py`             | Switching between the three installed Python versions         |
| `GoLang.Go`                  | Go 1.26          | Go projects                                                   |
| `Microsoft.DotNet.SDK.8`     | .NET SDK 8       | Dependency of several tools                                   |
| `LeNgocKhoa.Laragon`         | Laragon          | Local PHP/MySQL stack. Kiosco-Diagonal runs here              |
| `Tailscale.Tailscale`        | Tailscale        | VPN to reach my own machines                                  |
| `Gyan.FFmpeg`                | FFmpeg           | Video/audio conversion from the terminal                      |
| `RARLab.WinRAR`              | WinRAR           | Archives. License has to be entered by hand                   |

## Terminal

These belong to the terminal but get installed in this phase — the `terminal/` folder
only holds **configuration**, not binaries.

| winget ID                      | What it is       | What I use it for                                                   |
| ------------------------------ | ---------------- | ------------------------------------------------------------------- |
| `Fastfetch-cli.Fastfetch`      | fastfetch        | The ASCII art on terminal startup                                    |
| `DEVCOM.JetBrainsMonoNerdFont` | JetBrainsMono NF | **Required** for the fastfetch glyphs and the terminal. Without it everything renders as hollow boxes. Registers as `JetBrainsMono NFM`, not the long name — see `terminal/README.md` |

## Desktop / utilities

| winget ID                     | What it is    | What I use it for      |
| ----------------------------- | ------------- | ---------------------- |
| `CharlesMilette.TranslucentTB` | TranslucentTB | Transparent taskbar    |
| `RamenSoftware.Windhawk`      | Windhawk      | Windows UI mods        |
| `Parsec.Parsec`               | Parsec        | Remote desktop         |
| `Parsec.ParsecVDD`            | Parsec VDD    | Virtual display for Parsec |
| `Famatech.RadminVPN`          | Radmin VPN    | Virtual LAN            |

---

## Optional

**Not installed** unless you run `install.ps1 -Optional`.

| winget ID                | What it is      | Why it's excluded                          |
| ------------------------ | --------------- | ------------------------------------------ |
| `Valve.Steam`            | Steam           | This is a work machine                     |
| `ElectronicArts.EADesktop` | EA app        | Same                                       |
| `Ubisoft.Connect`        | Ubisoft Connect | Same                                       |
| `Logitech.GHUB`          | G HUB           | Only if you're using Logitech peripherals  |
| `Ollama.Ollama`          | Ollama          | Local models. Heavy and you barely use it  |
| `SST.OpenCodeDesktop`    | OpenCode        | You already have the CLI via npm           |
| `Anthropic.Claude`       | Claude Desktop  | The app; the CLI is installed from `claude/` |
| `Famatech.Radmin.Server` | Radmin Server   | Only if this machine is the host           |
| `Microsoft.Teams`        | Teams           | Only if work requires it                   |
| `Apple.Bonjour`          | Bonjour         | Leftover, unused                           |
| `Warp.Warp`              | Warp            | Dropped 2026-07-27 — not used any more     |
| `JanDeDobbeleer.OhMyPosh` | Oh My Posh     | Dropped 2026-07-27 — was installed for months but never wired into the profile, so the prompt stayed plain PowerShell. Don't like it, don't reinstall |

> `Microsoft.VCRedist.*`, `Microsoft.DotNet.*Runtime*` and `WindowsAppRuntime.*` are **not**
> in any table on purpose — they get pulled in automatically as dependencies.

---

## Fonts

`DEVCOM.JetBrainsMonoNerdFont` installs machine-wide into `C:\Windows\Fonts`, so it
**needs an elevated shell**. `install.ps1` checks for admin and warns instead of failing
silently — a font that didn't install produces hollow boxes everywhere and no error.

It registers as `JetBrainsMono NFM` (Nerd Font Mono), **not** `JetBrainsMono Nerd Font Mono`.
Getting that name wrong costs you the font without any warning. Details in
`terminal/README.md`.

**Not covered here:** the 12 Meslo Nerd Font families on this machine. They came from Oh
My Posh's own installer (`oh-my-posh font install meslo`), aren't on winget, and nothing
depends on them now that the JetBrains name is correct.

---

## Node — handled separately

Node does **not** come from winget. On this machine it lives in `C:\Briar\Code\Node`
(outside Program Files), and `install.ps1` pulls the official zip and unpacks it there.

| Package | Version  | What for                                  |
| ------- | -------- | ----------------------------------------- |
| `node`  | v24.12.0 | Runtime                                   |
| `pnpm`  | 10.25.0  | Enabled through `corepack enable`         |
| `uv`    | 0.11.20  | Python package manager. Goes to `~\.local\bin` |

## npm globals

| Package                 | What for                                                     |
| ----------------------- | ------------------------------------------------------------ |
| `oh-my-claude-sisyphus` | **OMC** — the Claude Code orchestration layer. See `claude/`  |
| `@anthropic-ai/sdk`     | SDK, for one-off scripts                                     |
| `@openai/codex`         | Codex CLI                                                    |
| `opencode-ai`           | OpenCode CLI                                                 |
| `chrome-devtools-mcp`   | Chrome DevTools MCP                                          |
| `hostinger-api-mcp`     | Hostinger MCP (hosting)                                      |
| `badclaude`             | —                                                            |

> `electron@41` was installed globally (~200 MB) but it normally belongs per-project.
> It does not get reinstalled; uncomment the line in `install.ps1` if you want it back.

---

## Keeping it current

```powershell
winget upgrade                              # see what's outdated
winget upgrade --all --include-unknown      # update everything
```

Run `snapshot.ps1` afterwards so `winget-export.json` reflects the new versions.

---

## `winget-export.json`

Raw output of `winget export`, holding **everything** that was installed on 2026-07-27
(78 packages, redistributables and games included). It's the backstop in case I forgot
something in the tables above.

**Generated file — don't hand-edit it.** `snapshot.ps1` regenerates it.
