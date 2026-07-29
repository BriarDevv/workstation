# workstation — repo instructions

This repo restores a Windows 11 machine from scratch. When you work here you're the one
**executing** the restore, not the one planning it again.

## Order

**Don't run the folders by hand — `install.ps1` at the root does it in order:**

```powershell
pwsh .\install.ps1              # everything
pwsh .\install.ps1 claude       # one folder
pwsh .\install.ps1 -WhatIfOnly  # preview
```

The order lives in that script's `$STEPS` table, which is what actually executes. Root
`README.md` shows it for a human reading the repo; if the two ever disagree, the script is
right.

`layout/` runs first because `apps/` unpacks Node inside the tree and `dev/` clones into it.
`apps/` installs binaries; every other folder configures them. Each folder has its own
`README.md` (what's there and why) and its own `install.ps1` that still runs standalone.
Read the README before running the script.

Two things the orchestrator will not do for you:

- **`terminal/` has no `-WhatIfOnly`.** A dry run skips it and says so, rather than pretending
  it was covered. Run it on its own to see what it does.
- **It stops after `apps/` if a reboot is pending**, and prints the command to resume. Docker
  and WSL don't exist until the restart, and everything after that configures programs.

**Target OS is Windows 11 Pro**, decided 2026-07-29 over Enterprise LTSC — it's what the
Retail licence activates. `winget` ships with it, so the folders normally just run; check
`Get-Command winget` anyway rather than assuming. `windows/bootstrap.ps1` is the fallback,
not the expected path.

Pro is the edition that **needs configuring**, which is the whole reason `windows/` matters:
it arrives with the inbox apps LTSC strips, so `windows/debloat.ps1` is load-bearing rather
than cosmetic. The `msstore` source works here — use it only where it's the sole source for
something wanted, and say so in the row.

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

**`layout/LAYOUT.md` is the only place a path under the layout root is written down.** Don't
hardcode one anywhere else — ask for it:

```powershell
. "$PSScriptRoot\..\_lib.ps1"
$dir = Get-LayoutPath 'node'
```

Most programs are **not** in that table and shouldn't be. The vendor default is the right
answer unless there's a reason, and `LAYOUT.md` holds both the exceptions and the reasons.
Git, VS Code, Docker, Chrome, PowerShell and the runtimes all go where winget puts them, so
resolve those at run time (`Get-Command git`) rather than assuming a path — hardcoding one
breaks on exactly the machine this repo exists to build.

User-level config is separate from all of this and moves with the user, not the install: VS
Code always reads `%APPDATA%\Code\User`, git always reads `~/.gitconfig`.

> **Until the format, the old hand-made tree is still on disk** next to the new one —
> `C:\Briar\Code\`, `Programas\`, `Pen\`, `Facultad\` and three empty folders, about 226 GB.
> It is not what this repo builds and nothing here maintains it. Much of it isn't installed
> software at all but **saved installers**: a folder there with one `.exe` inside is a
> download, not a program. Root `README.md` § *Before you wipe* is the decision record.

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
