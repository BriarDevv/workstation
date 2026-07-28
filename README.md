# workstation

My machine, in a repo. Wipe Windows, run one prompt, get back to work.

Not a dotfiles repo copied off the internet: this is the real state of **this** machine,
captured 2026-07-27, and it gets updated as things change.

---

## After a fresh install

**1.** Install the bare minimum by hand — the only manual step:

```powershell
winget install Git.Git Microsoft.PowerShell GitHub.cli
```

Close the window and open **PowerShell 7** (`pwsh`).

**2.** Authenticate, clone, install Claude Code:

```powershell
gh auth login          # account BriarDevv, HTTPS — the repo is private, this comes first
git clone https://github.com/BriarDevv/workstation.git $HOME\workstation
cd $HOME\workstation
irm https://claude.ai/install.ps1 | iex
claude
```

> The repo is **private**, so `git clone` fails until `gh auth login` has run. That's the
> one extra step private costs you — and `gh auth login` was on the manual list anyway.

**3.** Paste this:

> Read the root README and the README in each folder. Get this machine ready to work,
> following the install order in the root README. Show me what you're doing, and stop if
> anything fails. At the end, tell me what's left to do by hand.

---

## The folders

Each folder answers exactly one question.

|                 | Answers                                              | How often you touch it                          |
| --------------- | ---------------------------------------------------- | ----------------------------------------------- |
| **`apps/`**     | Which programs go on, and why I have each one        | When you install something new you want to keep  |
| **`terminal/`** | How does the terminal look                           | When you change the style                        |
| **`dev/`**      | How is my dev environment set up — VS Code, Git, repos | When you change editor config or add a repo    |
| **`claude/`**   | How does Claude operate                              | **Often.** This one moves the most               |
| **`windows/`**  | How is the OS set up — LTSC, winget bootstrap, Explorer | Almost never                                  |
| **`secrets/`**  | Only `.env.example`. Real keys never get committed    | When you add a new service                       |

`apps/` installs binaries; every other folder configures them. Windows Terminal is
installed by `apps/` and configured by `terminal/` — same pattern everywhere.

### Install order

```
0. windows/  bootstrap   winget, if LTSC didn't bring it
1. apps/                 the binaries
2. terminal/             the look
3. dev/                  VS Code, Git, repos
4. claude/               Claude Code
5. windows/  the rest    Explorer tweaks — restarts Explorer
```

Apps early because everything after it configures programs that have to exist already.
`windows/` is split: the winget bootstrap has to run before anything, the Explorer tweaks
run last because they restart Explorer.

Each folder has its own `README.md` (what's there and why) and its own `install.ps1`
(how it gets applied). They run standalone:

```powershell
pwsh .\install.ps1              # everything, in order
pwsh .\install.ps1 claude       # just Claude
pwsh .\claude\install.ps1       # same thing
```

Scripts are **idempotent**: running them twice breaks nothing, and anything they
overwrite gets backed up to `$HOME\.workstation-backup\`.

---

## Secrets

This repo holds **no credentials**. `.gitignore` blocks:

- `~/.claude.json` — your Claude OAuth token
- `~/.claude/mcp-configs/mcp-servers.json` — used to hold **8 API keys in plaintext**
  (Jira, GitHub PAT, Firecrawl, Exa, FAL, Browserbase, Confluence, OpenAI)
- any `.env`, `*.key`, `*.pem`

What ships instead: `claude/mcp.template.json` with `${VAR}` placeholders, and
`secrets/.env.example` listing what to restore and where to regenerate each key.

---

## Keeping it current

The repo goes stale on its own. After installing or configuring anything:

```powershell
pwsh .\snapshot.ps1
git add -A ; git commit -m "chore: snapshot $(Get-Date -f yyyy-MM-dd)"
```

`snapshot.ps1` re-reads the machine and writes the current state back over the repo.

---

## Status

| Folder      | Docs | `CLAUDE.md` | `install.ps1` | Notes                                       |
| ----------- | ---- | ----------- | ------------- | ------------------------------------------- |
| `apps/`     | ✅   | —           | ✅ tested     | Reads winget IDs straight out of the README |
| `terminal/` | ✅   | ✅          | ✅ tested     | Style system: one file per look             |
| `dev/`      | ✅   | —           | ❌ missing    | —                                           |
| `claude/`   | ✅   | —           | ❌ missing    | —                                           |
| `windows/`  | ✅   | —           | ✅ tested     | `bootstrap.ps1` + `install.ps1` + `usb.md`  |
| root        | ✅   | ✅          | ❌ missing    | Needs `install.ps1` + `snapshot.ps1`        |

`windows/` also has **`usb.md`** — building the install USB, verified against the actual
stick that was built.

Lives at **`github.com/BriarDevv/workstation`**, private.

Still to come: `debloat.ps1`, deliberately left until Windows is installed and there's a
real machine to judge against.

### Target OS: Windows 11 Enterprise LTSC

Decided 2026-07-27. Two things this changes:

- **`winget` may not exist on a fresh install** — it ships with the Microsoft Store, which
  LTSC drops. Nothing in this repo runs without it. See `windows/README.md` § Bootstrap.
- **The current Windows 11 Pro Retail licence does not activate LTSC.** Different product.
  It stays the way back: reinstalling Pro on this board reactivates itself.

### Keeping the repo in sync — the split

Two different problems, two different tools:

- **Mechanical inventory** → `snapshot.ps1`. Installed packages, VS Code extensions, npm
  globals. No judgment involved, so a script is strictly better: deterministic, instant,
  and it can't invent anything.
- **Layered config** → the folder's `CLAUDE.md` + an agent. Deciding whether a changed
  value belongs to the style, the scheme or the base is a judgment call. A script would
  have to guess, and guessing wrong flattens the composition. `terminal/CLAUDE.md` writes
  the routing rules down instead.

The `CLAUDE.md` isn't a cheap substitute for the script — it's what stops an agent from
copying a composed `settings.json` back over the base and destroying the style system.
It's needed either way.

### Decided

- **Oh My Posh** — dropped 2026-07-27. Installed for months but never wired into the
  profile, so the prompt stayed plain PowerShell. Not wanted.
- **Warp** — dropped 2026-07-27, not used any more.
- **Color schemes** — only Catppuccin Mocha survives. Sakura Pink, Dracula and
  Color Scheme 15 removed.
- **`--dangerously-skip-permissions`** in `terminal/powershell/profile.ps1` overrides
  whatever `defaultMode` you set in `claude/settings.json`. Left as-is deliberately.

---

## Before you wipe — read this

These folders are **not on any remote**. Wipe the machine and they're gone:

```
C:\Briar\Facultad     C:\Briar\Trabajo     C:\Briar\WAND
C:\Briar\Pen          C:\Briar\Paginas
```

Copy them to an external drive or push them to a private repo first.
