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
| `merge.ff = only`           | **Local merges fail.** Merging happens in a PR — see below   |
| `push.default = current`    | `git push` pushes this branch to the branch of the same name |
| `push.autoSetupRemote`      | First push of a new branch sets its upstream by itself       |
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

```powershell
git checkout -b feat/thing
# work, commit
git push                       # no -u, no remote name: autoSetupRemote handles it
gh pr create --fill
```

Then merge it on GitHub. Back on `main`, `git pull` rebases and you're current.

`merge.ff = only` is what keeps you honest. `git merge feat/thing` on a `main` that has
moved doesn't quietly produce a merge commit — it refuses:

```
hint: Diverging branches can't be fast-forwarded, you need to either:
hint:   git merge --no-ff
```

> **This is a guardrail, not enforcement.** Nothing in a local config can stop anyone —
> including you, ten seconds later — from typing `git merge --no-ff`, and that escape hatch
> is deliberate: the config catches the merge you didn't mean to make, not the one you did.
>
> Real enforcement is **branch protection on GitHub**: require a pull request before merging
> on `main`. That's server-side and per-repository, so it can't live in this file and this
> repo doesn't try to script it. Turn it on in each repo's settings — it's the half that
> actually holds.

---

## `repos/`

One `.md` per list, and `install.ps1` reads all of them — so splitting them by owner, by
client or by anything else costs nothing, and adding a list means adding a file.
`repos/README.md` has the format.

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
