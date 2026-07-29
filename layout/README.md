# Layout

The folder tree the machine keeps, and the one place its paths are written down.

`LAYOUT.md` is the source. This file explains it; the scripts read it.

---

## `install.ps1`

```powershell
pwsh layout\install.ps1
pwsh layout\install.ps1 -WhatIfOnly     # report every action, perform none
```

Three steps: create the folders, drop a copy of `LAYOUT.md` at the root, then fix the root's
permissions.

**It runs first.** `apps/` unpacks Node inside the tree and `dev/` clones into it, so both
need it to exist already.

Idempotent, and it exits 1 with a named list when something doesn't complete — the same
contract as `apps/` and `dev/`.

---

## Where the folders come from

Two sources, and neither is this file:

| Folder                              | Comes from                                       |
| ----------------------------------- | ------------------------------------------------ |
| `apps\`, `dev\`, `games\`, `repos\` | The rows in `LAYOUT.md` marked `Created = yes`    |
| `repos\mine\`, `repos\external\`, … | One per `.md` in `dev/repos/`, named after the file |

The second one is why adding a category costs a single file: create `dev/repos/clients.md`
and `repos\clients\` appears on the next run, with the clones going into it. There is no
second place to register it, so there is no second place to forget.

The copy of `LAYOUT.md` at the root of the tree is documentation left where it will be found
— for whoever opens that folder without this repo in front of them. It is never read back:
`Get-LayoutRows` uses the repo's copy, so the two can't become rival inputs.

---

## The permissions step

`C:\Briar` was created by hand at the root of `C:` and inherited that ACL, which grants
**`Authenticated Users`** write access to everything below it. `Program Files` does not work
that way:

| Path | Who can write |
| ---- | ------------- |
| `C:\Program Files` | SYSTEM, Administrators, TrustedInstaller |
| `%LOCALAPPDATA%\Programs` | the above **+ the user** |
| `C:\Briar` **before** this step | the above **+ `Authenticated Users`** |

So the script drops inheritance and re-grants SYSTEM, Administrators and you — landing on the
`%LOCALAPPDATA%\Programs` shape.

### Two things about that code that look wrong and aren't

**`icacls`, not `Set-Acl`.** `Set-Acl` cannot remove an inherited ACE. `RemoveAccessRule`
returns `$true`, `Set-Acl` raises nothing, and the entry is still there afterwards — measured
on this machine, twice. A permissions change that fails silently is worse than one that
doesn't run.

**The explicit grant back to you is not belt-and-braces.** `C:` gives `BUILTIN\Users` only
`ReadAndExecute`. Drop inheritance without re-granting and the tree goes read-only for any
unelevated session, which is every session — and the first thing to break is `dev/`'s clones,
several steps later, for a reason that looks nothing like permissions.

Neither needs elevation. Being the folder's owner is enough.

---

## What this folder does not do

- **It doesn't move anything.** It creates folders and sets one ACL. Programs put themselves
  where `LAYOUT.md` says at install time — see `apps/`.
- **It doesn't clean up.** The old hand-made tree is the format's problem, and root
  `README.md` § *Before you wipe* is the decision record for what gets written off.
- **It doesn't decide where a program goes.** `LAYOUT.md` § *Which folder* does, in four rows,
  so the question is answered the same way twice.
