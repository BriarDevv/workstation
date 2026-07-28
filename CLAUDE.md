# workstation — repo instructions

This repo restores a Windows 11 machine from scratch. When you work here you're the one
**executing** the restore, not the one planning it again.

## Order

```
0. windows/  bootstrap   winget, if LTSC didn't bring it
1. apps/                 the binaries
2. terminal/             the look
3. dev/                  Git, repos
4. claude/               Claude Code
5. windows/  the rest    Explorer tweaks — restarts Explorer
```

`apps/` installs binaries; every other folder configures them. Each folder has its own
`README.md` (what's there and why) and its own `install.ps1`. Read the README before
running the script.

**Target OS is Windows 11 Enterprise LTSC.** It ships without the Microsoft Store, and
`winget` comes from the Store — so on a fresh install nothing here runs until App Installer
is put in by hand. Check `Get-Command winget` before assuming anything works.

`apps/` installs Docker and WSL, which **require a reboot**. Warn and stop there.

## Hard rules

**Never commit secrets.** Before any `git add`, verify none of these slipped in:
`secrets/*` (except `.env.example`), `claude/mcp.json`, `.env`, `*.key`, `*.pem`.
`.gitignore` already blocks them — don't loosen it.

**The tables are the complete list.** Every README here describes the machine as it should
be, not the history of what it used to be. If something isn't in a table, it isn't wanted —
don't add it back, and don't record removals: a repo that carries a list of software the
owner rejected is a repo that ships its own contamination. When you drop something, delete
the row.

**Never name a project.** `dev/repos/` is the one place allowed to, because listing
repositories is its entire job and it is quarantined for exactly that reason. Anywhere else
— install scripts, READMEs, git config, Claude config, code comments — a project name is a
bug. What this repo installs serves many projects at once, so justifying a package, an
extension or a setting by naming one of them is both wrong and guaranteed to rot: the
project ends, the machine doesn't. Describe the shape of the problem instead of the repo you
last hit it in. Per-project knowledge belongs in a `CLAUDE.md` inside that project.

**Latest stable, never pinned.** Everything this repo installs is the newest **stable**
release as of the moment you run it — not a snapshot of what was current when the script
was written. Resolve versions from the vendor at run time (`releases/latest`,
`nodejs.org/dist/index.json`, the npm `latest` dist-tag) and upgrade what's already
installed on every run, not just what's missing. "Stable" means the vendor's stable
channel: Node **LTS** not Current, .NET **LTS** not preview, `Microsoft.PowerShell` not
`Microsoft.PowerShell.Preview`. A literal version in a script is only ever an offline
fallback and must carry a comment saying so. `-SkipUpgrade` is the escape hatch.

**Scripts are idempotent.** If you touch one, it has to stay safe to run twice. Check
before creating; never `New-Item -Force` on a file that might already exist (it truncates).

**Back up before overwriting.** Any script that writes into `$HOME` copies the original
to `$HOME\.workstation-backup\<date>\` first.

**PowerShell 7 (`pwsh`), not PS5.** The scripts use `&&`, ternaries and `??`. If
`$PSVersionTable.PSVersion.Major -lt 7`, stop.

**The `.txt` files in `terminal/ascii-arts/` are assets, not docs.** fastfetch reads them
raw. Don't convert them to `.md` and don't reformat them.

## Paths on this machine

Personal repos live in `C:\Users\mateo\Desktop\`.

`C:\Briar\Code\` holds Node, Git and VS Code **on the machine as it stands today** — but be
careful, because **the restore only reproduces one of them**:

| | Today | After running this repo |
| --- | --- | --- |
| **Node** | `C:\Briar\Code\Node` | same — `apps/install.ps1` unpacks the zip there on purpose |
| **Git** | `C:\Briar\Code\Git` | `C:\Program Files\Git` — winget's default |
| **VS Code** | `C:\Briar\Code\VSC\Microsoft VS Code` | `%LOCALAPPDATA%\Programs\Microsoft VS Code` — winget's default |
| **Docker** | `C:\Program Files\Docker` | same. The `Code\Docker` folder is just the saved installer |

So don't hardcode `C:\Briar\Code\Git` or the VS Code path into anything. Resolve them
(`Get-Command git`), or they'll break on exactly the machine this repo exists to build.
User-level config is unaffected either way: VS Code always reads `%APPDATA%\Code\User`, git
always reads `~/.gitconfig`.

Most of `C:\Briar\Code\` and `C:\Briar\Programas\` isn't installed software at all — it's
**saved installers**, about 2 GB of them. A folder there with one `.exe` inside is a
download, not a program.

**There is no local PHP/MySQL stack on this machine.** Don't write anything that assumes
one.

## Language

Docs and comments in this repo are written in **English**. Keep it that way, including
comments inside `.ps1` and `.json` files.

## When you're done

Report honestly: what came out green, what failed, and what needs manual work (logins,
2FA, API keys). Don't claim success without the real command output.

`apps/install.ps1` exits **1** when something didn't install, and prints two lists you must
pass on rather than summarise away: what failed, and **"things this script cannot install"**
— the `Manual afterwards` section of `apps/README.md`. That second list is not a footnote.
Those are programs the user wants and will not get unless someone tells them, and a restore
that ends with "all done" while four apps are silently missing is a worse outcome than one
that ends with a to-do list.
