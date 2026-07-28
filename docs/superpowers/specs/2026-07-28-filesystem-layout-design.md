# Filesystem layout — design

**Date:** 2026-07-28
**Status:** design agreed in conversation, **not yet approved in writing**. Section 8 lists
what is still open.

Replaces the hand-made `C:\Briar\` tree with one the repo creates and documents, and adds a
`layout/` folder that owns it.

---

## 1. Why the current tree fails

Measured on 2026-07-28, before the format.

| Problem | Evidence |
| ------- | -------- |
| Two folders do the same job | `Code\` and `Programas\` both mix installed programs with saved installers. Git, Node and VS Code are in `Code`; Windhawk is in `Programas`. No rule explains the split |
| A path doesn't say what a thing is | `Code\Docker` is 573 MB in **1 file** — a downloaded `.exe`. `Code\Git` is 404 MB in **9,614 files** — an installed program. Same depth, same naming style, opposite meaning |
| The weight hides under a generic name | `Programas\Juegos` is **217 GB** of the 219 GB in that folder |
| Folders created by intention, never filled | `Paginas`, `Trabajo`, `WAND` are empty |
| Mixed languages | `Programas`, `Juegos`, `Paginas`, `Facultad` next to `Code`, `Pen` |
| Nothing writes the rules down | Every save is a fresh decision, so identical things end up in different places |

The root cause is not naming. **The path carries no type and no write permission**, so
neither a person nor an agent can tell what they found without opening it.

### The root is also weakly protected

| Path | Who can write |
| ---- | ------------- |
| `C:\Program Files` | SYSTEM, Administrators, TrustedInstaller |
| `%LOCALAPPDATA%\Programs` | the above **+ the user** |
| `C:\Briar` | the above **+ `Authenticated Users`** |

Created by hand at the root of `C:`, it inherited the permissive root ACL. Any account with
a session can modify anything inside it.

---

## 2. Scope

Decided in conversation:

- **Everything lives in the tree, including the repos.** The Desktop stops holding checkouts.
- **Everything on `C:`.** The 932 GB `F:` drive is ~10 years old and slow; the SSD is the
  fast one. The tree does not span drives.
- **Root stays `C:\Briar\`.**
- **Design for the machine after the format**, not for what exists today.

---

## 3. The tree

```
C:\Briar\
  repos\
    mine\        the 6 repos
    external\    only if external.md exists
  dev\
    node\
  games\
    Steam\
    Riot Games\
  apps\          declared in LAYOUT.md, not created
  LAYOUT.md
```

### The rule that decides a folder

| Do you run it to… | Folder |
| ----------------- | ------ |
| write code | `dev\` |
| use it | `apps\` |
| play | `games\` |
| it is your own code | `repos\` |

Node is `dev\` because you never open it — your projects invoke it. Without a written
question like this, "is Node an app or a dev tool?" gets answered differently each time,
which is how `Code` and `Programas` became one folder with two names.

### No folder is created by intention

A folder exists only once something occupies it. `apps\` and `repos\external\` are declared
in `LAYOUT.md` and created on first use. This is the rule the empty `Paginas`, `Trabajo` and
`WAND` broke.

---

## 4. The list file name is the folder name

`dev/repos/<name>.md` maps to `C:\Briar\repos\<name>\`.

| List in the repo | Folder on disk |
| ---------------- | -------------- |
| `dev/repos/mine.md` | `C:\Briar\repos\mine\` |
| `dev/repos/external.md` | `C:\Briar\repos\external\` |

**Consequence: the `Destination` column disappears.** It is six identical cells today, each
of which can be mistyped and all of which must stay in sync. The table becomes:

```markdown
| Repo            | Remote                      |
| --------------- | --------------------------- |
| Bystellabotella | `BriarDevv/Bystellabotella` |
```

`repos\external\` is not created until `external.md` exists.

---

## 5. Install locations

`layout/` owns paths. Other scripts read them from it — `apps/install.ps1` currently
hardcodes `C:\Briar\Code\Node`, which would become a second source of truth for a value
`LAYOUT.md` already states. A `Get-LayoutPath` helper in `_lib.ps1`, same mechanic as
`Get-IdsFromReadme`.

### Why the vendor default wins by default

| Reason | Detail |
| ------ | ------ |
| ACL | Program Files needs admin to write. A path of your own does not — see § 1 |
| Updaters return to the default | Many self-updaters ignore the old location on a major update, leaving two copies |
| winget loses correlation | Override the path and an upgrade can stop seeing the package |
| Some installers ignore `--location` | Silently, with no error |

### The only three reasons to override

| Case | Instance here |
| ---- | ------------- |
| No vendor default exists | Node ships as a zip |
| The vendor supports relocation as its documented path | Steam libraries |
| Size changes the equation | 126 GB does not follow the same policy as a 40 MB tool |

### The table

Everything not listed installs to its vendor default — that is the intended answer, not a
gap.

| Package | Path | Why it's an exception |
| ------- | ---- | --------------------- |
| Node | `C:\Briar\dev\node` | Ships as a zip; there is no default to respect |
| `Valve.Steam` | `C:\Briar\games\Steam` | Vendor-supported relocation |
| `RiotGames.LeagueOfLegends.LA2` | `C:\Briar\games\Riot Games` | Same, and 43 GB |

Git, VS Code, Docker, Chrome, PowerShell and the twelve VC++ runtimes stay where winget
puts them.

---

## 6. What the tree does not own

**If Windows already has a folder for it, use Windows'.**

| Thing | Where |
| ----- | ----- |
| Downloads, installers | `Downloads`, deleted after use |
| Screenshots | `Pictures\Screenshots` |
| PDFs, receipts, loose files | `Documents` |
| Afternoon experiments | The Desktop, deliberately — created, then deleted |
| A project's design files | Inside that project's repo, versioned with it |

No `inbox`, no `media`, no `design`, no `scratch`. A folder of yours that competes with one
the system already provides always loses: programs save to Windows', you save to yours, and
the same kind of file ends up in two places. That is the `Code` vs `Programas` bug one level
up.

Throwaway code that might survive is created directly in `repos\mine\` and deleted if it
doesn't earn its place.

---

## 7. What gets built

New folder `layout/`, running **before** `apps/` because Node lands in `dev\node\`:

```
0. windows/ bootstrap
1. layout/            <- new
2. apps/
3. terminal/
4. dev/
5. claude/
6. windows/ rest
```

`layout/install.ps1` creates the tree **and tightens the root ACL** — removing the inherited
`Authenticated Users` entry so the root matches `%LOCALAPPDATA%\Programs` semantics. A
manual `mkdir` never does this, which is why the current root is world-writable.

| What | How |
| ---- | --- |
| `repos\`, `dev\`, `games\` | `layout/install.ps1` |
| `repos\mine\` | created because `mine.md` exists |
| Root ACL hardening | `layout/install.ps1` |
| `LAYOUT.md` at the root | copied from `layout/` |
| Node into `dev\node\` | `apps/install.ps1`, reading the path from `LAYOUT.md` |
| The repos into `repos\mine\` | `dev/install.ps1` |
| Steam into `games\Steam\` | `winget --location`. **Unverified** — see § 8 |
| League into `games\Riot Games\` | **Manual.** Its installer asks for the path |

### Files that change

| File | Change |
| ---- | ------ |
| `layout/` | New: `install.ps1`, `README.md`, `LAYOUT.md` |
| `dev/repos/mine.md` | Drop the `Destination` column |
| `dev/install.ps1` | Derive the path from the list file's name |
| `apps/install.ps1` | Node path read from `LAYOUT.md`, not hardcoded |
| `apps/README.md` | Steam and League: location note + a row in "Manual afterwards" |
| `_lib.ps1` | Add `Get-LayoutPath` |
| `README.md` | Install order, folder table |
| `CLAUDE.md` | The "today vs after the restore" path table becomes obsolete |

---

## 8. Open

1. **`winget --location` on Steam is unverified.** The manifest is `nullsoft`, and winget
   translates `--location` to NSIS `/D=` for that type, so it should work — but it was not
   tested, and installing Steam to find out was not worth it before the format. If it
   fails, Steam joins League as a manual step. The manifest declares no installer switches.
2. **League is manual** and this is not a gap to close: the installer is a plain `exe` with
   no declared switches, so `--location` almost certainly does nothing.
3. The design has **not** had a final written approval; the conversation ended before it.
4. Not yet written: the implementation plan.

---

## 9. Still open from before this design

Unrelated to the layout, carried so it isn't lost:

- `claude/install.ps1` does not exist. When it applies `mcp.template.json` it will create
  **duplicate MCP servers** for `playwright`, `chrome-devtools` and `context7`, each of
  which is already an enabled plugin. `claude/plugins.md` documents this exact bug for one
  of them and says "only one survives" — both survived.
- The root `install.ps1` orchestrator does not exist.
- `snapshot.ps1` does not exist. Its scope is now just the npm globals.
- The live `~/.gitconfig` is 9 lines against this repo's 16 settings; it has never been
  applied.
