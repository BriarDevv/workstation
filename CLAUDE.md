# workstation — repo instructions

This repo restores a Windows 11 machine from scratch. When you work here you're the one
**executing** the restore, not the one planning it again.

## Order

```
0. windows/  bootstrap   winget, if LTSC didn't bring it
1. apps/                 the binaries
2. terminal/             the look
3. dev/                  VS Code, Git, repos
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

Node, Git and VS Code are **not** in `Program Files` — they live under `C:\Briar\Code\`.
Personal repos live in `C:\Users\mateo\Desktop\`. If a script assumes standard paths, it's
wrong.

Laragon used to live there too and served Kiosco-Diagonal out of
`C:\Briar\Code\Laragon\www\`. It was dropped 2026-07-28, so **there is no local PHP/MySQL
stack on this machine any more** — don't write anything that assumes one.

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
