# Dev

git, and the repos to clone. The programs themselves come from `apps/` — this folder only
configures them.

---

## `install.ps1`

```powershell
pwsh dev\install.ps1
pwsh dev\install.ps1 -WhatIfOnly     # report every action, perform none
pwsh dev\install.ps1 -SkipRepos      # config only, clone nothing
```

Two steps: `~/.gitconfig`, then the clones. git goes first on purpose — `credential.helper`
is what lets the clones authenticate without a token sitting in a file.

The clones need `layout\install.ps1` to have run first — that's what creates the folder they
go into, and it's why layout is step 1 of the install order.

It **configures**; it does not install programs. git and `gh` both come from `apps/`, and
when one is missing this says so and carries on rather than trying to fetch it.

The repository lists are read out of `repos/`, so a row there remains the only place any of
them exists. Failures are collected, printed together at the end, and the script exits 1:
the same contract as `apps/`.

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

### Merging goes through a pull request

The practice: branch, push, open a PR, rebase-merge it on GitHub. Never merge into `main`
locally.

```powershell
git checkout -b feat/thing
# work, commit
git push -u origin feat/thing
gh pr create --fill
```

**That rule is not enforced from this file, on purpose.** It would be easy to add
`merge.ff = only` here and make `git merge` refuse — but a global setting that makes a
normal command fail is a trap, not a guardrail. Whoever hits it next, months from now, sees
an error they didn't ask for and has to work backwards to a line in a file they weren't
thinking about. `pull.rebase` earns its place because everybody already knows what it does
and nothing breaks when it's on; `merge.ff = only` doesn't clear that bar.

Enforcement belongs to the repository, not the machine — **branch protection on GitHub**,
set per repo:

| Setting                         | Value               | What it buys                          |
| ------------------------------- | ------------------- | ------------------------------------- |
| `required_pull_request_reviews` | on, **0** approvals | Forces a PR; you can still merge your own without waiting |
| `required_linear_history`       | on                  | No merge commits reach `main`         |
| Merge methods                   | rebase only         | Merge commits and squash both off     |
| `allow_force_pushes`            | off                 | —                                     |
| `allow_deletions`               | off                 | —                                     |

That's server-side, so it survives a format and applies to every machine you touch the repo
from — which is why it's the half worth having, and why nothing here tries to script it.

---

## `repos/`

One `.md` per list, and `install.ps1` reads all of them — so splitting them by owner, by
client or by anything else costs nothing, and adding a list means adding a file.
`repos/README.md` has the format.

**Where they land comes from the list file's name**, not from a column: `mine.md` clones into
`repos\mine\` under the root `layout/LAYOUT.md` declares. `layout/install.ps1` creates that
folder from the same filename, so adding a list is still one file — and the folder and the
clones can't end up disagreeing about where it is.

Kept out of this file deliberately: this one describes the **machine**, those describe the
**work**, and the two go stale at completely different speeds.

---

## Why VS Code isn't in here

**VS Code Settings Sync owns it.** Signing in restores settings, keybindings and every
extension, so a copy in this repo wouldn't be a backup — it would be a second source of
truth for the same three things.

That fails quietly, which is the problem. Change a setting in the editor, Sync stores it,
this repo doesn't have it, and the next run of a script silently puts the old value back.
Two config systems agreeing today is exactly the state in which nobody notices they've
diverged.

So the restore path for the editor is: `apps/` installs VS Code, you sign in, Sync does the
rest. Nothing here touches `%APPDATA%\Code\User`.

> If you ever turn Sync off, this is the decision to revisit — not by re-adding the files
> quietly, but by writing down which one wins.
