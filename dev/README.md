# Dev

The development environment: editor, git, and the repos to clone. The programs themselves
come from `apps/` — this folder only configures them.

---

## `install.ps1`

```powershell
pwsh dev\install.ps1
pwsh dev\install.ps1 -WhatIfOnly     # report every action, perform none
pwsh dev\install.ps1 -SkipRepos      # config only, clone nothing
```

Three steps in order: VS Code config and extensions, then `~/.gitconfig`, then the clones.
git comes before the clones on purpose — `credential.helper` is what lets them authenticate
without a token in a file.

It **configures**; it does not install programs. VS Code, git and `gh` all come from
`apps/`, and when one is missing this says so and carries on rather than trying to fetch it.

Both lists are read out of the markdown beside it — extension IDs from
`vscode/extensions.md`, repositories from `repos.md` — so a row remains the only place
either list exists. Failures are collected, printed together at the end, and the script
exits 1: the same contract as `apps/`.

There is no upgrade pass for extensions and no `-SkipUpgrade` to suppress one. VS Code
updates them itself (`extensions.autoUpdate` defaults to on and `settings.json` doesn't
override it), so "latest stable, always" already holds without reinstalling every extension
on every run to discover that.

---

## `vscode/`

| File               | What it is                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| `settings.json`    | Catppuccin Mocha, sidebar on the right, activity bar on top, no minimap, ruler at 120, Prettier per language   |
| `keybindings.json` | One binding: `Shift+Enter` in the terminal sends `ESC + CR` (newline without executing)                        |
| `extensions.md`    | The extensions, grouped by what they're for. That table is the whole list                      |

Installs to `%APPDATA%\Code\User\`.

### Font

`editor.fontFamily` and `terminal.integrated.fontFamily` are both `JetBrainsMono NFM`,
matching the terminal. That name is deliberate and not obvious — read
`../terminal/README.md` § "Font names lie" before changing it. The short version: Windows
falls back silently when a family name doesn't resolve, and the long form
`JetBrainsMono Nerd Font Mono` is not what winget registers.

`editor.fontLigatures` is on, which only does anything because the family above resolves —
Consolas, the silent fallback, has no ligatures.

`pwsh terminal\install.ps1 -SyncEditorFont` rewrites both keys from the active terminal
style, so the editor follows whatever font the terminal is using.

---

## `git/gitconfig`

Installs to `~/.gitconfig`.

| Setting                     | Why                                                          |
| --------------------------- | ------------------------------------------------------------ |
| `user.name` / `user.email`  | Mateo · mateogarcia1660@gmail.com                            |
| `pull.rebase = true`        | Linear history, no junk merge commits                        |
| `rebase.autostash = true`   | Stashes and restores loose changes when rebasing             |
| `core.autocrlf = true`      | Windows ↔ repos that use LF                                  |
| `core.longpaths = true`     | Windows truncates at 260 chars; `node_modules` blows past it |
| `core.editor = code --wait` | Commit messages and interactive rebases open in VS Code      |
| `credential.helper`         | Delegates to `gh` — no tokens in the config file             |
| `init.defaultBranch = main` | —                                                            |
| `fetch.prune = true`        | Cleans up dead remote branches on fetch                      |
| `diff.colorMoved = zebra`   | Moved lines render differently from added ones               |

Aliases: `s` (short status), `lg` (graph log), `last`, `unstage`, `amend`.

**Manual afterwards:** `gh auth login` → account `BriarDevv`, HTTPS, scopes
`gist, read:org, repo, workflow`. There's no way to script an OAuth flow.

---

## Repos to clone

In **`repos.md`**, deliberately not here. This file describes the machine; that one
describes the work, and the work list goes stale far faster than the machine does.

`install.ps1` reads that table directly, so the script never carries a second copy of it.

> ⚠️ Some folders on this disk are on **no remote at all** and nothing here clones them.
> Root `README.md` § **Before you wipe** has the list.
