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
| **`layout/`**   | Where things live on disk, and the permissions on it | Almost never                                     |
| **`apps/`**     | Which programs go on, and why I have each one        | When you install something new you want to keep  |
| **`terminal/`** | How does the terminal look                           | When you change the style                        |
| **`dev/`**      | How is git set up, and which repos get cloned         | When you add or drop a repo                     |
| **`claude/`**   | How does Claude operate                              | **Often.** This one moves the most               |
| **`windows/`**  | How is the OS set up — LTSC, winget bootstrap, Explorer | Almost never                                  |
| **`secrets/`**  | Only `.env.example`. Real keys never get committed    | When you add a new service                       |

`apps/` installs binaries; every other folder configures them. Windows Terminal is
installed by `apps/` and configured by `terminal/` — same pattern everywhere.

### Install order

```
0. windows/  bootstrap   winget, if LTSC didn't bring it
1. layout/               the folder tree
2. apps/                 the binaries
3. terminal/             the look
4. dev/                  Git, repos
5. claude/               Claude Code
6. windows/  the rest    Explorer tweaks — restarts Explorer
```

Layout first because `apps/` unpacks Node inside the tree and `dev/` clones into it, so both
need it to exist. Apps next because everything after it configures programs that have to be
there already. `windows/` is split: the winget bootstrap has to run before anything, the
Explorer tweaks run last because they restart Explorer.

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

## Versions

**Latest stable, always.** Nothing here is pinned. Every script resolves versions from the
vendor at run time and upgrades what's already installed, so a restore gives you today's
releases instead of a snapshot of the day the script was written.

"Stable" means the vendor's stable channel, not the newest thing that exists — Node **LTS**
rather than Current, .NET **LTS** rather than preview. Pass `-SkipUpgrade` to hold versions
still for a run.

Two exceptions, both documented where they live:

- the **offline fallback** version in `apps/install.ps1`, used only when `nodejs.org` can't
  be reached;
- **a major version baked into a winget ID** — `Python.Python.3.14`. winget treats every
  major as a separate package, so `winget upgrade` goes 3.14.0 → 3.14.6 but never
  3.14 → 3.15. That one moves by editing the table in `apps/README.md`.

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

`snapshot.ps1` re-reads the machine and refreshes the lists the repo already owns.

---

## Status

| Folder      | Docs | `CLAUDE.md` | `install.ps1` | Notes                                       |
| ----------- | ---- | ----------- | ------------- | ------------------------------------------- |
| `layout/`   | ✅   | —           | ✅ tested     | Creates the tree from `LAYOUT.md`; hardens the root |
| `apps/`     | ✅   | —           | ✅ tested     | Reads winget IDs straight out of the README |
| `terminal/` | ✅   | ✅          | ✅ tested     | Style system: one file per look             |
| `dev/`      | ✅   | —           | ✅ tested     | Reads extension IDs and repos from markdown |
| `claude/`   | ✅   | —           | ✅ tested     | Merges `settings.json`; won't clobber OMC's hooks |
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

- **Mechanical inventory** → `snapshot.ps1`. The npm globals — a list the repo already owns,
  refreshed in place. No judgment involved, so a script is strictly better: deterministic,
  instant, and it can't invent anything.

  It's a short job on purpose. VS Code extensions aren't here because Settings Sync owns
  them, and the installed-package set isn't either.

  It deliberately does **not** dump the installed-package list. A raw `winget export` is a
  photo of the machine rather than a wish list, so it carries back every program the tables
  leave out — which is precisely how software you removed reappears in the repo that was
  supposed to have dropped it.
- **Layered config** → the folder's `CLAUDE.md` + an agent. Deciding whether a changed
  value belongs to the style, the scheme or the base is a judgment call. A script would
  have to guess, and guessing wrong flattens the composition. `terminal/CLAUDE.md` writes
  the routing rules down instead.

The `CLAUDE.md` isn't a cheap substitute for the script — it's what stops an agent from
copying a composed `settings.json` back over the base and destroying the style system.
It's needed either way.

### Decided

- **The tables are the complete list.** What isn't in them isn't wanted. This repo doesn't
  keep a record of software that was rejected — that's contamination, not documentation.
  When something is dropped, the row goes with it.
- **`--dangerously-skip-permissions`** in `terminal/powershell/profile.ps1` overrides
  whatever `defaultMode` you set in `claude/settings.json`. Left as-is deliberately.

---

## Before you wipe — read this

**Decided 2026-07-28: nothing gets backed up.** Everything wanted is on GitHub, everything
else gets reinstalled. `C:\Briar\Pen`, `Facultad`, `WAND`, `Trabajo` and `Paginas` are
written off on purpose — that's a decision, not an oversight.

That was verified rather than assumed. All **11** git repositories on this machine have a
remote, and every one reports **zero unpushed commits** (checked against a live `git fetch`,
not stale refs).

### Except stashes. Nothing pushes those.

A stash lives in `.git/refs/stash` and **no `git push` ever uploads it**, not even
`--all`. It looks safe because it's "in git". It isn't.

```
git stash list          # in every repo, before wiping
```

There were five across all repos on 2026-07-28, reviewed and written off deliberately.
Count them again before wiping: that number is only true for the day it was taken.

To keep one, turn it into something the remote can hold:

```powershell
git stash branch keep/<name> stash@{0}   # replays it onto a new branch
git push -u origin keep/<name>
```

The other thing worth a glance is `??` entries in `git status` — an untracked file that
belongs in the repo looks exactly like one that doesn't.

Read the path before acting on it. A lockfile sitting untracked at a repo root can be a stub
while the one that actually pins the dependencies lives in a subdirectory and has been
tracked all along. The alarming filename and the file that matters are not always the same
file.

> **This is the only copy of that list.** `windows/usb.md`, `windows/README.md` and
> `dev/README.md` each used to repeat it — four places to keep in sync for the one list
> where being out of date costs you data that doesn't exist anywhere else. They point here
> now. If you add a folder, add it here and nowhere else.
