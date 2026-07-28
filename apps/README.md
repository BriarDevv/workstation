# Apps

Which programs I have and **why**. The "what for" column is the important one — in eight
months you won't remember what TranslucentTB was doing here.

`install.ps1` reads the winget IDs out of the tables below (the ones in `backticks` in the
first column). Add a row and it gets installed on the next run.

## winget is not the Microsoft Store

Easy to conflate, and on this machine the difference decides whether the restore works at
all. winget has **sources**. The `winget` source is a community-maintained catalogue of
manifests that point at the vendor's own download — chrome from google.com, the font from
GitHub, League from Riot. The `msstore` source is the Microsoft Store, and it needs the
Store to be installed.

**Every package in the tables below comes from the `winget` source, and none from
`msstore`** — checked per row, as a condition of adding it. That matters because the target OS is LTSC,
which has no Store: anything sourced from `msstore` simply cannot resolve there.

Exactly one wanted program is Store-only — the NVIDIA App — which is why it sits under
§ Manual afterwards instead of in a table.

## How it reports

A failed package doesn't stop the run. Failures are collected and printed together at the
end, then the script **exits 1**. A restore that halted on the first bad package leaves you
worse off than one that finished and told you what's missing — and the important lines are
exactly the ones that scrolled past you two hundred lines ago.

```
=== Summary
  [ok]   nothing failed
```

The reboot warning only appears when something that actually needs one — Docker or WSL —
was installed **on that run**. A warning that fires every single time is a warning you stop
reading.

If `winget` itself is missing, the script points at `windows/bootstrap.ps1` — not at the
Microsoft Store, which on the target OS isn't there to go to.

---

## Versions — latest stable, always

Nothing here is pinned. `install.ps1` upgrades **every package in the tables** on every
run, not only the ones it just installed. That covers all four sources — winget packages,
Node itself, the npm globals, and pnpm/uv. Pass `-SkipUpgrade` to hold versions still for
one run.

"Stable" means the vendor's stable channel, not the newest thing that exists: Node **LTS**
rather than Current, .NET **LTS** rather than preview, `Microsoft.PowerShell` rather than
`Microsoft.PowerShell.Preview`.

Two places still carry a literal version, and both are deliberate:

- **The Node fallback in `install.ps1`.** The version is resolved from `nodejs.org` at run
  time; the literal only applies when the site can't be reached.
- **A major version baked into a winget ID** — `Python.Python.3.14`. winget treats every
  major as a separate package, so `winget upgrade` will take 3.14.0 → 3.14.6 but never
  3.14 → 3.15. That one moves by editing the table.

---

## Essentials

Nothing works without these. All of them get installed.

| winget ID                    | What it is       | What I use it for                                            |
| ---------------------------- | ---------------- | ------------------------------------------------------------ |
| `Git.Git`                    | Git              | Obvious. Currently in `C:\Briar\Code\Git`, but winget restores it to Program Files — see root `CLAUDE.md` |
| `GitHub.cli`                 | `gh`             | PRs, issues and cloning without opening a browser. Account `BriarDevv` |
| `Microsoft.PowerShell`       | PowerShell 7     | This repo's scripts use `&&` and `??`, which PS5 doesn't have |
| `Microsoft.WindowsTerminal`  | Windows Terminal | Daily driver                                                  |
| `Microsoft.VisualStudioCode` | VS Code          | Main editor                                                   |
| `Google.Chrome`              | Chrome           | **The only browser here.** LTSC ships without Edge preinstall, so without this row a restored machine cannot open a web page at all |
| `Docker.DockerDesktop`       | Docker           | Containers. **Requires a reboot**                             |
| `Microsoft.WSL`              | WSL2             | Linux for whatever doesn't run on Windows. **Requires a reboot** |
| `Python.Python.3.14`         | Python 3.14      | The system-wide one. Projects use their own — see § Python    |
| `Python.Launcher`            | `py`             | `py -3.14`, and what shebangs resolve through                 |
| `Tailscale.Tailscale`        | Tailscale        | VPN to reach my own machines                                  |
| `RARLab.WinRAR`              | WinRAR           | Archives. License has to be entered by hand                   |

## Terminal

These belong to the terminal but get installed in this phase — the `terminal/` folder
only holds **configuration**, not binaries.

| winget ID                      | What it is       | What I use it for                                                   |
| ------------------------------ | ---------------- | ------------------------------------------------------------------- |
| `Fastfetch-cli.Fastfetch`      | fastfetch        | The ASCII art on terminal startup                                    |
| `DEVCOM.JetBrainsMonoNerdFont` | JetBrainsMono NF | **Required** for the fastfetch glyphs and the terminal. Without it everything renders as hollow boxes. Registers as `JetBrainsMono NFM`, not the long name — see `terminal/README.md` |

## Desktop / utilities

| winget ID                      | What it is     | What I use it for                                     |
| ------------------------------ | -------------- | ----------------------------------------------------- |
| `CharlesMilette.TranslucentTB` | TranslucentTB  | Transparent taskbar. Runs from the tray                |
| `Discord.Discord`              | Discord        | Daily. Starts with the session                         |
| `Anthropic.Claude`             | Claude Desktop | The app. The CLI is a separate install, from `claude/` |
| `Logitech.GHUB`                | G HUB          | The peripherals. Starts with the session               |
| `Spotify.Spotify`              | Spotify        | Music. Per-user install into `%APPDATA%\Spotify`       |

> **Spotify is the one package that can fail _because_ you ran the script elevated.** Its
> installer is a per-user `exe` that refuses to run as Administrator, while § Fonts asks for
> an elevated shell. A single run can't satisfy both.
>
> Nothing breaks if it happens: the failure is collected and named in the summary like any
> other, and re-running unelevated installs it while skipping everything already there. Do
> the elevated run first for the font, then a plain one.

## Games

| winget ID                        | What it is       | Notes                                                        |
| -------------------------------- | ---------------- | ------------------------------------------------------------ |
| `Valve.Steam`                    | Steam            | Also a **dependency**: Wallpaper Engine is sold only through it |
| `RiotGames.LeagueOfLegends.LA2`  | League of Legends | **LA2 = LAS**, the Latin America South server                |

Two traps in that second row:

- winget has **eight** League packages, one per server — `.BR`, `.EUNE`, `.EUW`, `.JP`,
  `.KR`, `.LA1`, `.LA2`, `.NA`. The wrong one installs a client for a region you don't play
  on. This account is LA2 / `es_AR`, read out of `LeagueClientSettings.yaml`.
- **There is no Riot Client package**, and none is needed — the client ships inside the
  League installer. A separate row would install the same thing twice.

## Runtimes

Runtime libraries that Windows doesn't ship and that native software links against.
Nothing here gets used directly — they're installed up front so that something built years
ago just runs, instead of stopping on a missing DLL.

Compatibility insurance, in other words. Cheap to install, annoying to diagnose: the
symptom is a program that won't start and an error naming a file you've never heard of.

| winget ID          | What it is       | Notes                                              |
| ------------------ | ---------------- | -------------------------------------------------- |
| `Microsoft.DirectX` | DirectX End-User Runtime | Version 9.29.1974.0 — the June 2010 redist. Windows 11 has DirectX 12 built in, but **not** the legacy `d3dx9_*`, `xinput1_3`, `xaudio2_7` and `d3dcompiler_4x` DLLs. Those only come from here |

Visual C++ runtimes, the whole set. Every program compiled with MSVC links against one of
these, and each release is a **separate** runtime — having 2013 does nothing for something
built against 2010. Six releases, and both architectures of each, is why the table is
twelve rows and not one:

| winget ID                      | Release  |
| ------------------------------ | -------- |
| `Microsoft.VCRedist.2005.x86`  | 2005     |
| `Microsoft.VCRedist.2005.x64`  | 2005     |
| `Microsoft.VCRedist.2008.x86`  | 2008     |
| `Microsoft.VCRedist.2008.x64`  | 2008     |
| `Microsoft.VCRedist.2010.x86`  | 2010     |
| `Microsoft.VCRedist.2010.x64`  | 2010     |
| `Microsoft.VCRedist.2012.x86`  | 2012     |
| `Microsoft.VCRedist.2012.x64`  | 2012     |
| `Microsoft.VCRedist.2013.x86`  | 2013     |
| `Microsoft.VCRedist.2013.x64`  | 2013     |
| `Microsoft.VCRedist.2015+.x86` | 2015–2022 |
| `Microsoft.VCRedist.2015+.x64` | 2015–2022 |

Both architectures, deliberately: a lot of software is still 32-bit, and the x64
redistributable does nothing for it.

`2015+` covers 2015, 2017, 2019 and 2022 — Microsoft made those binary-compatible, so one
package serves all four. The older five are not compatible with each other.

> There's a well-known community AIO repack (`abbodi1406.vcredist`) that installs all of
> these from one `.exe`. Passed over on purpose: it's a third-party repackaging of Microsoft
> binaries, and twelve extra rows in a table cost nothing next to taking installers for
> system runtimes from someone other than the vendor.

---

## Optional

**Not installed** unless you run `install.ps1 -Optional`.

| winget ID                  | What it is      | Why it's excluded                               |
| -------------------------- | --------------- | ----------------------------------------------- |
| `Ollama.Ollama`            | Ollama          | Local models. Multi-GB downloads per model, so it's off the default path |

> `Microsoft.DotNet.*Runtime*` and `WindowsAppRuntime.*` are **not** in any table on
> purpose — they get pulled in automatically as dependencies.
>
> That reasoning does **not** extend to § Runtimes, and the difference is easy to miss:
> automatic dependency resolution only happens for programs installed **through winget**,
> which declare what they need. Anything installed another way — a store client, an archive
> you unpacked, an old installer — declares nothing.

---

## Manual afterwards

Wanted on the machine, but **winget can't deliver them**. Checked 2026-07-28. They're
listed here rather than left out, so that a restore ends with a short honest to-do instead
of you discovering the gap weeks later.

| What | Why it can't be scripted | Where to get it |
| ---- | ------------------------ | --------------- |
| **Porofessor** | No winget package exists at all — `winget search Porofessor` returns nothing | porofessor.gg |
| **NVIDIA App** | Only published to **msstore** (`XP8CLZL93F5Z4P`), and the target OS is LTSC, which has no Microsoft Store. That source can't resolve there | nvidia.com |
| **Wallpaper Engine** | Sold exclusively through Steam. The winget hit named "Wallpaper Engine" is `Taiizor.SucroseWallpaperEngine`, a different open-source project | Steam (already installed by § Games) |
| **Pencil** | `Pencil.Desktop` exists, but the manifest sits at **1.1.26** while this machine runs **1.1.70**. Installing from winget would be a downgrade, and would pin you there until someone updates the manifest — the opposite of § Versions. It updates itself | pencil.dev |

Also by hand, for reasons that have nothing to do with winget:

| What | Why |
| ---- | --- |
| **WinRAR licence** | The key has to be typed in |
| **`gh auth login`** | An OAuth flow can't be scripted. See `dev/README.md` |

---

## Fonts

`DEVCOM.JetBrainsMonoNerdFont` installs machine-wide into `C:\Windows\Fonts`, so it
**needs an elevated shell**. `install.ps1` checks for admin and warns instead of failing
silently — a font that didn't install produces hollow boxes everywhere and no error.

It registers as `JetBrainsMono NFM` (Nerd Font Mono), **not** `JetBrainsMono Nerd Font Mono`.
Getting that name wrong costs you the font without any warning. Details in
`terminal/README.md`.

A restored machine gets **exactly** the one font in that table and nothing else — which is
why the name has to be right.

---

## PowerShell lands in WindowsApps, not Program Files

`winget show Microsoft.PowerShell` reports `Installer Type: msix`. So on a restored machine
`C:\Program Files\PowerShell\7` **never exists** — PowerShell 7 lives in
`%LOCALAPPDATA%\Microsoft\WindowsApps\` and is reached through the `pwsh.exe` app execution
alias.

**Never hardcode that Program Files path.** Call `pwsh.exe` and let the alias resolve it;
that works whichever flavour is installed. `terminal/windows-terminal/settings.json` is the
one place this matters — a default profile pointing at a path winget never creates means the
first terminal you open after a format fails to start.

### winget won't always see a program you installed by hand

winget only tracks what it installed. A program put on the machine another way — a vendor
MSI, an unpacked archive — often fails to correlate to its package, so `winget list` reports
it as missing and `install.ps1` installs a second copy alongside it, in winget's own
location. Harmless on a fresh machine, where nothing pre-exists. Worth knowing if you ever
install something by hand that's also in the tables above.

---

## Python

`Python.Python.3.14` is the system-wide interpreter and it exists **for the shell** — `py`,
one-off scripts, anything run outside a project. It is the only Python this repo installs.

**Projects don't use it.** They pin their own interpreter through `uv`, which downloads
whatever version they declare into `%APPDATA%\uv\python\` on demand. So a project resolves
the same on a fresh machine whether or not the winget Python is there, and the version in
the table has no bearing on it.

---

## Node — handled separately

Node does **not** come from winget. On this machine it lives in `C:\Briar\Code\Node`
(outside Program Files), and `install.ps1` pulls the official zip and unpacks it there.

| Package | Version                | What for                                       |
| ------- | ---------------------- | ---------------------------------------------- |
| `node`  | latest **LTS**         | Runtime. Resolved at run time — see § Versions  |
| `pnpm`  | whatever corepack ships | Enabled through `corepack enable`              |
| `uv`    | latest                 | Python package manager. Goes to `~\.local\bin` |

Node follows the **LTS** line, not Current: on 2026-07-28 that was v24.18.0 while Current
was v26.5.0. If a project ever needs Current, that's a per-project decision, not a machine
one.

An outdated Node is replaced in place. The new tree is fully extracted before the old
directory is moved aside, and the old one is only deleted once the new one has landed.
Nothing is lost in the swap — global packages live in `%APPDATA%\npm`, not here.

## npm globals

| Package                 | What for                                                     |
| ----------------------- | ------------------------------------------------------------ |
| `oh-my-claude-sisyphus` | **OMC** — the Claude Code orchestration layer. See `claude/`  |
| `@anthropic-ai/sdk`     | SDK, for one-off scripts                                     |
| `chrome-devtools-mcp`   | Chrome DevTools MCP                                          |
| `hostinger-api-mcp`     | Hostinger MCP (hosting)                                      |

### Where the binaries go

The Node **zip** ships its own `npmrc` with `prefix=${APPDATA}\npm`, so `npm i -g` puts
executables in `%APPDATA%\npm` and not next to `node.exe`. The zip sets no environment
variables, so nothing puts that folder on `PATH`.

`install.ps1` adds it explicitly. Without that, a fresh machine installs `omc` and the two
MCP servers with no errors at all and then can't run any of them. It goes unnoticed on the
current machine only because an old Node MSI added the entry years ago.

### `npmrc`

Installs to `~/.npmrc`. One line, `ignore-scripts=true`: dependencies can't run
`postinstall` code just because you installed them. It applies to every npm install on the
machine, not only global ones.

When a package legitimately needs its install script, allow it for that command —
`npm install --ignore-scripts=false`, or `npm rebuild <package>` — rather than deleting the
line. All four globals above install cleanly with it on (verified 2026-07-28).

---

## Keeping it current

`install.ps1` upgrades every package in the tables on each run — see § Versions. That's the
intended path and it's deliberately scoped: it touches what this repo asked for, and nothing
else on the machine.

To sweep everything instead, including whatever was installed outside this repo:

```powershell
winget upgrade                              # see what's outdated
winget upgrade --all --include-unknown      # update everything
```
