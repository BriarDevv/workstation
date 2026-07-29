# Filesystem layout — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `layout/` folder that creates and owns the `C:\Briar\` tree, and make every
other script read its paths from it instead of holding literals.

**Architecture:** `layout/LAYOUT.md` holds one markdown table that is the only place a path
under the layout root is written down — the same "the table is the source" mechanic
`apps/README.md` already uses for winget IDs. Two helpers in `_lib.ps1` read it:
`Get-LayoutRows` (everything, for the script that creates the tree) and `Get-LayoutPath`
(one path by key, for everyone else). `layout/install.ps1` creates the folders and hardens
the root's ACL, and runs first in the install order because Node lands inside the tree.

**Tech Stack:** PowerShell 7, markdown tables, `icacls`, winget.

**Spec:** `docs/superpowers/specs/2026-07-28-filesystem-layout-design.md`

---

## There is no test framework in this repo

Every script here is a Windows restore script whose only real test is running it. So
"verify" in this plan always means **run the command and read the output**, and the
project's `CLAUDE.md` already sets the bar: *"Don't claim success without the real command
output."*

Every task's verification follows the same three-beat shape, because it is what the repo's
own contract demands:

| Beat | Why |
| ---- | --- |
| `-WhatIfOnly` first | The dry run is only trustworthy if it is exercised. It must name every action the real run performs |
| Then for real | Read the output. It must match what the dry run promised |
| Then **again**, for real | `CLAUDE.md`: *"Scripts are idempotent. If you touch one, it has to stay safe to run twice."* The second run must report skips, not repeated work |

## Global Constraints

Copied from `CLAUDE.md`. Every task inherits all of them.

- **PowerShell 7 (`pwsh`), not PS5.** Scripts use `&&`, ternaries and `??`. If
  `$PSVersionTable.PSVersion.Major -lt 7`, stop.
- **Scripts are idempotent.** Safe to run twice. Check before creating; **never
  `New-Item -Force` on a file that might already exist** (it truncates). `-Force` on a
  *directory* is fine and is how parents get created.
- **Back up before overwriting.** Anything writing into `$HOME` copies the original to
  `$HOME\.workstation-backup\<date>\` first — `Install-ConfigFile` already does this.
- **Docs and comments in English**, including inside `.ps1` and `.json`.
- **Never name a project.** `dev/repos/` is the only place allowed to.
- **The tables are the complete list.** What isn't in them isn't wanted. Don't record
  removals.
- **Latest stable, never pinned.** A literal version is only ever an offline fallback and
  must carry a comment saying so.
- **Never commit secrets.** Before any `git add`, verify none of `secrets/*` (except
  `.env.example`), `claude/mcp.json`, `.env`, `*.key`, `*.pem` slipped in.

## Measured facts this plan is built on

Taken on this machine on 2026-07-28/29, not assumed. The code below depends on all four.

| Fact | Measurement |
| ---- | ----------- |
| `C:\` grants `BUILTIN\Users` only `ReadAndExecute` | `(Get-Acl 'C:\').Access` |
| …so removing `Authenticated Users` **without** re-granting the user leaves the tree read-only in an unelevated session — and every session is unelevated | same, plus `IsInRole(Administrator)` → `False` |
| `Set-Acl` **cannot** remove an inherited ACE. `RemoveAccessRule` returns `True`, `Set-Acl` reports no error, and the ACE survives | reproduced on a folder with an inherited `Authenticated Users` ACE |
| `icacls /inheritance:r` + explicit grants does it correctly, **unelevated**, and is idempotent across runs | two consecutive passes, exit 0, writes into fresh subfolders still work |

That third row is the reason this plan uses `icacls` rather than the .NET ACL API. The
`Set-Acl` route fails **silently**, which is the worst possible way for a permissions change
to fail.

---

## File Structure

| File | Responsibility |
| ---- | -------------- |
| `layout/LAYOUT.md` | **New.** The one table. Every path under the layout root, and whether the restore creates it |
| `layout/install.ps1` | **New.** Creates the tree; hardens the root ACL |
| `layout/README.md` | **New.** What the folder is for and the rule that decides where a thing goes |
| `_lib.ps1` | Add `Get-LayoutRows` and `Get-LayoutPath` |
| `dev/repos/external.md` | **New.** Headers, no rows — this is what makes `repos\external\` exist |
| `dev/repos/mine.md` | Drop the `Destination` column |
| `dev/repos/README.md` | Document the 2-column format and the filename→folder rule |
| `dev/install.ps1` | Derive the destination from the list file's name |
| `dev/README.md` | Say where clones land now |
| `apps/install.ps1` | Node path from `LAYOUT.md`; pass `--location` when a row declares one |
| `apps/README.md` | Node § path, Games § note, Manual afterwards § entry |
| `README.md` | Install order, folder table, status table |
| `CLAUDE.md` | Replace the obsolete "today vs after the restore" path table |

---

### Task 1: `LAYOUT.md` and the two helpers that read it

Nothing else in the plan works until a script can ask "where does X go?" and get an answer
from one file.

**Files:**
- Create: `layout/LAYOUT.md`
- Modify: `_lib.ps1` (append after `Get-RowsFromReadme`, around line 206)

**Interfaces:**
- Produces: `Get-LayoutRows()` → array of `@{ Key; Path; Created }` where `Created` is
  `[bool]`. `Get-LayoutPath -Key <string> [-IfDeclared]` → `[string]` path, throws when
  there is no row unless `-IfDeclared`, which returns `$null`.
- Consumed by: Tasks 2, 3, 4, 5, 6.

- [ ] **Step 1: Write `layout/LAYOUT.md`**

One table, four columns. `Created` is exactly `yes` or `no` so the parse is not a judgment
call. Column 1 and 2 are backticked; the parser requires it.

````markdown
# Layout

Everything the machine keeps lives under one root, and **this table is the only place any of
those paths is written down**. A script that needs one asks `Get-LayoutPath`; it never holds
a literal. Move a folder by editing a row here.

## Paths

| Key                             | Path                        | Created | What it is                                                        |
| ------------------------------- | --------------------------- | ------- | ----------------------------------------------------------------- |
| `root`                          | `C:\Briar`                  | yes     | The root. Nothing loose at this level                              |
| `apps`                          | `C:\Briar\apps`             | yes     | A program you open, when it has no vendor default to respect       |
| `dev`                           | `C:\Briar\dev`              | yes     | A tool your projects invoke rather than you                        |
| `games`                         | `C:\Briar\games`            | yes     | Games and their launchers                                          |
| `repos`                         | `C:\Briar\repos`            | yes     | Your own code. One subfolder per list in `dev/repos/`              |
| `node`                          | `C:\Briar\dev\node`         | no      | `apps/install.ps1` unpacks the zip here                            |
| `Valve.Steam`                   | `C:\Briar\games\Steam`      | no      | `winget --location`                                                |
| `RiotGames.LeagueOfLegends.LA2` | `C:\Briar\games\Riot Games` | no      | Its installer asks — see `apps/README.md` § Manual afterwards      |

`Created = no` means something else puts it there, so creating it up front would only race
whatever does.

## Which folder

| Do you run it to… | Folder    |
| ----------------- | --------- |
| write code        | `dev\`    |
| use it            | `apps\`   |
| play              | `games\`  |
| it is your code   | `repos\`  |

Node is `dev\` because you never open it — your projects invoke it. The question has to be
written down or it gets answered differently each time, which is how one machine ends up
with two folders that do the same job.

## An empty folder is fine. An undocumented one is not

Every folder in the table is created by the restore whether or not anything occupies it yet,
so the slot is already there the day you need it. What makes that safe is the last column:
an empty folder that says what belongs in it reads as *nothing has needed this yet*, not as
*someone gave up*.

The rule both ways round:

- a folder in this table exists, empty or not;
- a folder **not** in this table shouldn't exist — it either earns a row or it goes.

Which makes the tree auditable: `dir C:\Briar` and this table must agree.

## What does not live here

If Windows already has a folder for it, use Windows'.

| Thing | Where |
| ----- | ----- |
| Downloads, installers | `Downloads`, deleted after use |
| Screenshots | `Pictures\Screenshots` |
| PDFs, receipts, loose files | `Documents` |
| Afternoon experiments | The Desktop, deliberately — created, then deleted |
| A project's design files | Inside that project's repo, versioned with it |

A folder of yours that competes with one the system already provides always loses: programs
save to Windows', you save to yours, and the same kind of file ends up in two places.

Throwaway code that might survive goes straight into `repos\mine\` and gets deleted if it
doesn't earn its place.
````

- [ ] **Step 2: Append both helpers to `_lib.ps1`**

```powershell
# ---------------------------------------------------------------- layout
# layout\LAYOUT.md is the only place a path under the layout root is written down, and these
# two are how a script asks. Holding a literal instead is what this exists to prevent: the
# second copy is never wrong on the day you write it, only on the day the tree moves.
#
# It reads the copy in the repo, not the one at the root of the tree. The one on disk is for
# whoever opens that folder in three years; the repo is what the scripts are built from, and
# the two can only disagree if something reads the wrong one.
function Get-LayoutRows {
    $md = Join-Path $script:RepoRoot 'layout\LAYOUT.md'
    if (-not (Test-Path $md)) { throw "layout\LAYOUT.md is missing - it is the source of every path under the layout root" }

    $rows = [System.Collections.Generic.List[hashtable]]::new()
    $inPaths = $false
    foreach ($line in Get-Content $md) {
        if ($line -match '^##\s+(.+?)\s*$') { $inPaths = ($Matches[1].Trim() -eq 'Paths'); continue }
        if (-not $inPaths) { continue }
        # Both cells backticked, which skips the header and the ---- separator for free.
        if ($line -notmatch '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*([^|]*)\|') { continue }
        $rows.Add(@{
                Key     = $Matches[1].Trim()
                Path    = $Matches[2].Trim()
                Created = $Matches[3].Trim() -eq 'yes'
            })
    }
    if (-not $rows.Count) { throw "layout\LAYOUT.md has no readable rows under '## Paths'" }
    return $rows
}

# Throws when there is no row, on purpose: a typo'd key returning $null would send an
# installer to whatever the working directory happened to be. -IfDeclared is for the one
# honest question - "does this package declare an override at all?" - where absence is the
# expected answer rather than a mistake.
function Get-LayoutPath {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$IfDeclared
    )
    $row = Get-LayoutRows | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
    if ($row) { return $row.Path }
    if ($IfDeclared) { return $null }
    throw "no row for '$Key' in layout\LAYOUT.md"
}
```

- [ ] **Step 3: Verify the parse against the real file**

Run:

```powershell
pwsh -NoProfile -Command ". .\_lib.ps1; Get-LayoutRows | ForEach-Object { '{0,-32} {1,-28} created={2}' -f `$_.Key, `$_.Path, `$_.Created }"
```

Expected — 8 rows, the first five `created=True`, the last three `created=False`:

```
root                             C:\Briar                     created=True
apps                             C:\Briar\apps                created=True
dev                              C:\Briar\dev                 created=True
games                            C:\Briar\games               created=True
repos                            C:\Briar\repos               created=True
node                             C:\Briar\dev\node            created=False
Valve.Steam                      C:\Briar\games\Steam         created=False
RiotGames.LeagueOfLegends.LA2    C:\Briar\games\Riot Games    created=False
```

**If the count is not 8, the regex is wrong — do not proceed.** The most likely cause is a
cell that lost its backticks.

- [ ] **Step 4: Verify lookups, including the two failure modes**

Run:

```powershell
pwsh -NoProfile -Command ". .\_lib.ps1; Get-LayoutPath node; Get-LayoutPath repos; Get-LayoutPath 'Valve.Steam'; (Get-LayoutPath nope -IfDeclared) ?? '<null, as expected>'; try { Get-LayoutPath nope } catch { 'threw: ' + `$_.Exception.Message }"
```

Expected:

```
C:\Briar\dev\node
C:\Briar\repos
C:\Briar\games\Steam
<null, as expected>
threw: no row for 'nope' in layout\LAYOUT.md
```

The last two lines are the point of the step. A silent `$null` from the throwing form is the
bug this design exists to make impossible.

- [ ] **Step 5: Commit**

```bash
git add layout/LAYOUT.md _lib.ps1
git commit -m "feat: LAYOUT.md declares every path under the layout root"
```

---

### Task 2: `layout/install.ps1` creates the tree

**Files:**
- Create: `layout/install.ps1`

**Interfaces:**
- Consumes: `Get-LayoutRows`, `Get-LayoutPath` (Task 1); `Write-Step`, `Write-Ok`,
  `Write-Skip`, `Write-Would`, `Write-Fail`, `Assert-PowerShell7`, `$script:DryRun` (existing
  `_lib.ps1`).
- Produces: `layout/install.ps1` accepting `-WhatIfOnly`, exit 0 on success and 1 with a
  named list on failure — the same contract as `apps/` and `dev/`.

- [ ] **Step 1: Write the script**

```powershell
<#
.SYNOPSIS
    Creates the folder tree and locks down its root.

.DESCRIPTION
    The tree is declared in LAYOUT.md and nowhere else - this script only reads it, so
    moving a folder is a one-line edit there rather than a hunt through scripts.

    Runs FIRST in the install order: apps/install.ps1 unpacks Node inside the tree, so the
    tree has to exist before it.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it isn't, and
    the summary names what.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh layout\install.ps1
    pwsh layout\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param([switch]$WhatIfOnly)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------- the tree
Write-Step 'Tree'

$wanted = [System.Collections.Generic.List[string]]::new()
foreach ($row in Get-LayoutRows | Where-Object { $_.Created }) { $wanted.Add($row.Path) }

# One folder per list in dev\repos\, derived rather than declared. Adding a list is adding a
# file - the same contract dev/install.ps1 already gives the clones - so a new category
# can't exist in one of the two places and not the other.
$reposRoot = Get-LayoutPath 'repos'
$listDir = Join-Path $PSScriptRoot '..\dev\repos'
foreach ($f in @(Get-ChildItem $listDir -Filter *.md -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name)) {
    $wanted.Add((Join-Path $reposRoot $f.BaseName))
}

foreach ($path in $wanted) {
    if (Test-Path $path) { Write-Skip $path; continue }
    if ($script:DryRun) { Write-Would "create $path"; continue }
    try {
        # -Force here creates missing parents. It is safe because the target is a directory;
        # the truncation hazard in CLAUDE.md is about -Force on a FILE.
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Ok $path
    }
    catch {
        Write-Fail "$path - $($_.Exception.Message)"
        $failed.Add($path)
    }
}

# ---------------------------------------------------------------- the map
# A copy of LAYOUT.md at the root of the tree, for whoever opens that folder without this
# repo in front of them - which on this machine is a real scenario, since the tree outlives
# any particular checkout of the repo that built it.
#
# The repo's copy stays the source: Get-LayoutRows reads that one, never this one. This is
# documentation left where it will be found, not a second input.
Write-Step 'Map'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'LAYOUT.md') (Join-Path (Get-LayoutPath 'root') 'LAYOUT.md'))) {
    $failed.Add('LAYOUT.md at the root')
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
Write-Host "  $($wanted.Count) folders declared" -ForegroundColor DarkGray

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host '  Re-running is safe and skips everything that already worked.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''
```

- [ ] **Step 2: Dry run — nothing may be created**

Run:

```powershell
pwsh layout\install.ps1 -WhatIfOnly
```

Expected: five `would create` lines — the `Created = yes` rows minus `C:\Briar` itself, which
already exists on this machine and so reports `[skip]`, plus `C:\Briar\repos\mine` — then
`would create C:\Briar\LAYOUT.md` under `=== Map`, and `6 folders declared`.

`repos\external` appears only after Task 4 adds `external.md`; at this point in the plan it
does not exist yet, and that is correct.

Then confirm the dry run really was one:

```powershell
pwsh -NoProfile -Command "Test-Path C:\Briar\apps, C:\Briar\dev, C:\Briar\games, C:\Briar\repos"
```

Expected: four `False`. **A `True` here means the dry run wrote to disk — stop and fix it
before anything else.**

- [ ] **Step 3: Run it for real**

Run:

```powershell
pwsh layout\install.ps1
```

Expected: `[ok]` for each folder created, then `[ok] nothing failed`, exit 0.

```powershell
pwsh -NoProfile -Command "Get-ChildItem C:\Briar -Directory | Select-Object -Expand Name; 'repos:'; Get-ChildItem C:\Briar\repos -Directory | Select-Object -Expand Name"
```

Expected: the new `apps`, `dev`, `games`, `repos` alongside whatever the old hand-made tree
still has, and `mine` under `repos`.

> The old `Code\`, `Programas\`, `Pen\`, `Facultad\`, `WAND\`, `Trabajo\`, `Paginas\` are
> **left exactly as they are**. Nothing in this plan deletes them — the format does that.
> Root `README.md` § *Before you wipe* is the decision record.

- [ ] **Step 4: Check the map landed**

```powershell
pwsh -NoProfile -Command "(Get-FileHash C:\Briar\LAYOUT.md).Hash -eq (Get-FileHash layout\LAYOUT.md).Hash"
```

Expected: `True`.

- [ ] **Step 5: Run it again — idempotency**

Run:

```powershell
pwsh layout\install.ps1
```

Expected: every folder line `[skip]`, no `[ok]` creations, and
`[skip] LAYOUT.md already identical` under `=== Map`. Exit 0.

**The `Map` step is the one that can break idempotency**, because it writes a file rather
than a directory. If it reports a backup on the second run, the hash comparison isn't
working and the repo's `$HOME\.workstation-backup\` will fill with copies.

- [ ] **Step 6: Commit**

```bash
git add layout/install.ps1
git commit -m "feat: layout/install.ps1 creates the tree from LAYOUT.md"
```

---

### Task 3: harden the root ACL

Separate from Task 2 because it is separately rejectable: the tree is useful even if this is
deferred, and this is the step that can lock the user out of their own disk if it is wrong.

**Files:**
- Modify: `layout/install.ps1` (insert between the tree section and the summary)

**Interfaces:**
- Consumes: `Get-LayoutPath 'root'`, `$failed`, `$script:DryRun`.
- Produces: nothing other scripts call.

**What "hardened" means here — the target end state, measured:**

| Identity | Rights |
| -------- | ------ |
| `NT AUTHORITY\SYSTEM` | FullControl |
| `BUILTIN\Administrators` | FullControl |
| the interactive user | FullControl |
| `NT AUTHORITY\Authenticated Users` | **absent** |

- [ ] **Step 1: Insert the permissions section**

Place immediately before `# ------- summary`.

```powershell
# ---------------------------------------------------------------- permissions
# C:\Briar was created by hand at the root of C: and inherited the root's ACL, which hands
# Authenticated Users write access to everything below it. Program Files does not work that
# way and neither should this.
#
# icacls rather than Set-Acl, and this is not a style preference. Set-Acl CANNOT remove an
# inherited ACE: RemoveAccessRule returns $true, Set-Acl reports no error, and the entry is
# still there afterwards. Measured on this machine. A permissions change that fails silently
# is worse than one that doesn't run.
#
# The three grants are not optional either. /inheritance:r drops every inherited entry, and
# C: only gives BUILTIN\Users ReadAndExecute - so without re-granting, an unelevated session
# (which is every session) would find the tree read-only and the clones in dev/ would fail.
# SIDs rather than names because the well-known ones are localised and these are not.
Write-Step 'Permissions'
$root = Get-LayoutPath 'root'

$acl = Get-Acl $root
$loose = @($acl.Access | Where-Object { $_.IdentityReference.Value -eq 'NT AUTHORITY\Authenticated Users' })

if (-not $acl.AreAccessRulesProtected -or $loose.Count) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($script:DryRun) {
        Write-Would "stop $root inheriting from C:\, drop Authenticated Users, grant SYSTEM, Administrators and $me full control"
    }
    else {
        # Splatted, not written inline. A native command takes its arguments as an array, and
        # writing them out with backticks and commas turns the commas into array literals -
        # icacls then sees one argument where it expected four and reports success anyway.
        $icaclsArgs = @(
            '/inheritance:r'
            '/grant', '*S-1-5-18:(OI)(CI)F'        # SYSTEM
            '/grant', '*S-1-5-32-544:(OI)(CI)F'    # BUILTIN\Administrators
            '/grant', "${me}:(OI)(CI)F"            # the interactive user
            '/q'
        )
        & icacls $root @icaclsArgs | Out-Null

        # icacls exit code alone isn't enough - re-read and check the thing we actually want.
        $after = Get-Acl $root
        $still = @($after.Access | Where-Object { $_.IdentityReference.Value -eq 'NT AUTHORITY\Authenticated Users' })
        $mine = @($after.Access | Where-Object { $_.IdentityReference.Value -eq $me -and $_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write })

        if ($LASTEXITCODE -eq 0 -and -not $still.Count -and $mine.Count) {
            Write-Ok "$root - Authenticated Users removed, $me keeps full control"
        }
        else {
            Write-Fail "$root - icacls exited $LASTEXITCODE, Authenticated Users present: $([bool]$still.Count), you can still write: $([bool]$mine.Count)"
            $failed.Add('root ACL')
        }
    }
}
else {
    Write-Skip "$root already hardened"
}
```

- [ ] **Step 2: Dry run**

Run:

```powershell
pwsh layout\install.ps1 -WhatIfOnly
```

Expected, under `=== Permissions`:

```
  would  stop C:\Briar inheriting from C:\, drop Authenticated Users, grant SYSTEM, Administrators and LONCHOS\mateo full control
```

Confirm it changed nothing:

```powershell
pwsh -NoProfile -Command "(Get-Acl C:\Briar).AreAccessRulesProtected"
```

Expected: `False` — still inheriting, because a dry run does not act.

- [ ] **Step 3: Record the ACL before changing it**

There is no undo for this and the folder currently holds ~219 GB. Capture the starting
state so a mistake is reversible by hand:

```powershell
pwsh -NoProfile -Command "icacls C:\Briar" | Tee-Object "$HOME\.workstation-backup\briar-acl-before.txt"
```

- [ ] **Step 4: Run for real and verify the end state**

Run:

```powershell
pwsh layout\install.ps1
pwsh -NoProfile -Command "(Get-Acl C:\Briar).AreAccessRulesProtected; (Get-Acl C:\Briar).Access | ForEach-Object { '{0,-34} {1}' -f `$_.IdentityReference, `$_.FileSystemRights }"
```

Expected:

```
True
NT AUTHORITY\SYSTEM                FullControl
BUILTIN\Administrators             FullControl
LONCHOS\mateo                      FullControl
```

No `Authenticated Users` row. **If one is still there, the run failed** even if the script
said otherwise — report it rather than moving on.

- [ ] **Step 5: Prove the tree is still writable**

The failure this guards against does not announce itself; it shows up three steps later as a
clone that won't clone.

```powershell
pwsh -NoProfile -Command "New-Item -ItemType Directory C:\Briar\repos\acl-probe -Force | Out-Null; Set-Content C:\Briar\repos\acl-probe\p.txt 'x'; Get-Content C:\Briar\repos\acl-probe\p.txt; Remove-Item C:\Briar\repos\acl-probe -Recurse -Force"
```

Expected: `x`. Anything else means the grants are wrong — restore from
`briar-acl-before.txt` and stop.

- [ ] **Step 6: Run again — idempotency**

```powershell
pwsh layout\install.ps1
```

Expected: `[skip] C:\Briar already hardened`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add layout/install.ps1
git commit -m "feat: harden the layout root ACL, dropping inherited Authenticated Users"
```

---

### Task 4: the list file's name is the folder

Three edits that cannot be split — the column and the code that reads it change together.

**Files:**
- Create: `dev/repos/external.md`
- Modify: `dev/repos/mine.md`, `dev/repos/README.md:24-35`, `dev/install.ps1:40-83`,
  `dev/README.md`

**Interfaces:**
- Consumes: `Get-LayoutPath 'repos'` (Task 1).
- Produces: `Get-ReposFromDir` keeps returning `@{ Name; Remote; Path; List }` — the
  consuming loop at `dev/install.ps1:115` is unchanged.

- [ ] **Step 1: Rewrite `dev/repos/mine.md` without the `Destination` column**

```markdown
# My repos

Everything under the `BriarDevv` account. Cloned and nothing else happens to them — no
symlinks, no per-project setup.

They land in `repos\mine\` because **this file is called `mine.md`**. See `README.md`.

## The list

| Repo                     | Remote                               |
| ------------------------ | ------------------------------------ |
| Bystellabotella          | `BriarDevv/Bystellabotella`          |
| Portafolio               | `BriarDevv/Portafolio`               |
| Ynara                    | `BriarDevv/Ynara`                    |
| Empoderamiento-Docente   | `BriarDevv/Empoderamiento-Docente`   |
| Inferiores-Riverplatense | `BriarDevv/Inferiores-riverplatense` |
| KioscoDiagonal           | `BriarDevv/Kiosco-Diagonal`          |
```

- [ ] **Step 2: Create `dev/repos/external.md`**

Headers and no rows. This file existing is the whole reason `repos\external\` exists.

```markdown
# External repos

Code that isn't yours — something you forked, something you're reading, a dependency you
need checked out locally.

Kept apart from `mine.md` for one reason: **you can delete anything in `repos\external\`
without thinking about it.** Whatever is in here came from somewhere else and can come from
there again. That is not true of `mine\`, and a folder you can't clear without checking
first is a folder that grows forever.

Empty is the normal state.

## The list

| Repo | Remote |
| ---- | ------ |
```

- [ ] **Step 3: Update the format section of `dev/repos/README.md`**

Replace lines 24-35 (`## The format` through `Cloning needs gh auth login done first.`):

````markdown
A file counts as a clone list when it has a `## The list` section holding a table:

| Column | What it is             |
| ------ | ---------------------- |
| 1      | The local folder name  |
| 2      | `owner/repo` on GitHub |

**Where they land comes from the file's own name.** `mine.md` clones into
`repos\mine\`, `external.md` into `repos\external\`, and the root of that comes from
`layout/LAYOUT.md`.

So adding a category is one file and nothing else:

```powershell
# repos\clients\ appears on the next run of layout\install.ps1
New-Item dev\repos\clients.md
```

There used to be a third column holding the destination. It was six identical cells, each of
which could be mistyped, and all of which had to be kept in step — a column that says the
same thing on every row isn't data, it's a chance to be wrong.

Anything outside a `## The list` section is prose and gets ignored, so a file can explain
itself without confusing the parser.

Cloning needs `gh auth login` done first.
````

Also update the file table near the top:

```markdown
| File          | What's in it                        |
| ------------- | ----------------------------------- |
| `mine.md`     | The `BriarDevv` repos               |
| `external.md` | Anyone else's. Empty, and that's fine |
```

- [ ] **Step 4: Rewrite `Get-ReposFromDir` in `dev/install.ps1`**

Replace the comment block and function at lines 40-83:

```powershell
# Every .md in repos\ except its README is a clone list, so adding a list is adding a file -
# there is nothing to register it in.
#
# The file's own name is the folder: mine.md clones into <repos>\mine\. That used to be a
# third column holding the destination, repeated identically on every row. layout\LAYOUT.md
# owns the root it hangs off, and layout\install.ps1 creates the folder from the same
# filename - so the two cannot disagree about where a list lives.
#
# These tables are shaped differently from the ones in apps/README.md: the useful columns
# are 1 and 2, and column 1 is plain text rather than a backticked ID. That's why
# Get-IdsFromReadme can't read them and this exists instead.
function Get-ReposFromDir {
    param([Parameter(Mandatory)][string]$Dir)

    $repos = [System.Collections.Generic.List[hashtable]]::new()
    if (-not (Test-Path $Dir)) { return $repos }

    $reposRoot = Get-LayoutPath 'repos'
    $files = Get-ChildItem $Dir -Filter *.md |
        Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name

    foreach ($file in $files) {
        # Reset per file: a table only counts inside a "## The list" section, which is what
        # lets each list explain itself in prose without confusing the parser.
        $inList = $false

        foreach ($line in Get-Content $file.FullName) {
            if ($line -match '^##\s+(.+?)\s*$') { $inList = ($Matches[1].Trim() -eq 'The list'); continue }
            if (-not $inList -or $line -notmatch '^\|') { continue }

            # A two-column row splits into 4 including the empty ends; 3 is the minimum that
            # still has both cells, which is all this indexes.
            $cells = $line -split '\|'
            if ($cells.Count -lt 3) { continue }

            $name = ($cells[1] -replace '\*\*|`', '').Trim()
            if (-not $name -or $name -match '^-+$' -or $name -eq 'Repo') { continue }

            $remote = ($cells[2] -replace '`', '').Trim()
            if (-not $remote -or $remote -match '^-+$') { continue }

            $repos.Add(@{
                    Name   = $name
                    Remote = $remote
                    Path   = Join-Path $reposRoot $file.BaseName $name
                    List   = $file.BaseName
                })
        }
    }
    return $repos
}
```

Note the added `$remote` guard: with the third column gone, the `| ---- | ------ |`
separator row now survives the `$name` check on some tables, and an empty remote would
produce a clone URL of `https://github.com/.git`.

- [ ] **Step 5: Verify the parse before cloning anything**

Run:

```powershell
pwsh dev\install.ps1 -WhatIfOnly
```

Expected — six clones, all under `C:\Briar\repos\mine\`, and **nothing from `external.md`**:

```
  would  clone BriarDevv/Bystellabotella -> C:\Briar\repos\mine\Bystellabotella
  would  clone BriarDevv/Portafolio -> C:\Briar\repos\mine\Portafolio
  would  clone BriarDevv/Ynara -> C:\Briar\repos\mine\Ynara
  would  clone BriarDevv/Empoderamiento-Docente -> C:\Briar\repos\mine\Empoderamiento-Docente
  would  clone BriarDevv/Inferiores-riverplatense -> C:\Briar\repos\mine\Inferiores-Riverplatense
  would  clone BriarDevv/Kiosco-Diagonal -> C:\Briar\repos\mine\KioscoDiagonal
```

and `6 repos across 2 list(s)`.

**Check the count is 6, not 7.** A seventh entry with an empty name or remote means the
separator row is getting through — the empty-table file is exactly what would expose that.

- [ ] **Step 6: Confirm `layout/install.ps1` now makes `repos\external\`**

```powershell
pwsh layout\install.ps1
pwsh -NoProfile -Command "Get-ChildItem C:\Briar\repos -Directory | Select-Object -Expand Name"
```

Expected: `external` and `mine`. This is the filename→folder rule working end to end — no
row was added anywhere to make `external` appear.

- [ ] **Step 7: Update `dev/README.md`**

Two edits.

In `## repos/`, after the first paragraph, add:

```markdown
**Where they land comes from the list file's name**, not from a column: `mine.md` clones
into `repos\mine\` under the root `layout/LAYOUT.md` declares. `layout/install.ps1` creates
that folder from the same filename, so adding a list is still one file and the folder and
the clones can't end up disagreeing about where it is.
```

In `## install.ps1`, after the paragraph ending *"…without a token sitting in a file."*, add:

```markdown
The clones need `layout\install.ps1` to have run first — that's what creates the folder they
go into, and it's why layout is step 1 of the install order.
```

- [ ] **Step 8: Clone for real**

Run:

```powershell
pwsh dev\install.ps1
pwsh -NoProfile -Command "Get-ChildItem C:\Briar\repos\mine -Directory | Select-Object -Expand Name"
```

Expected: the six repos. If `gh auth login` hasn't been run this reports it and exits 1 —
that is the documented path, not a failure of this task.

> The existing checkouts on the Desktop are **left alone**. Nothing here moves or deletes
> them; they are already pushed and the format removes them.

- [ ] **Step 9: Run again — idempotency**

```powershell
pwsh dev\install.ps1
```

Expected: six `[skip] <name> already cloned`, exit 0.

- [ ] **Step 10: Commit**

```bash
git add dev/repos/mine.md dev/repos/external.md dev/repos/README.md dev/install.ps1 dev/README.md
git commit -m "refactor: the repo list's filename is its folder, dropping the Destination column"
```

---

### Task 5: Node's path comes from `LAYOUT.md`

**Files:**
- Modify: `apps/install.ps1:113`, `apps/README.md:263-266`

**Interfaces:**
- Consumes: `Get-LayoutPath 'node'` (Task 1).

- [ ] **Step 1: Replace the literal**

`apps/install.ps1:113` is currently:

```powershell
$nodeDir = 'C:\Briar\Code\Node'
```

Replace with:

```powershell
# layout\LAYOUT.md owns this. A literal here would be the second place the path is written
# down, and the tree it points into is created by a script that reads the first one.
$nodeDir = Get-LayoutPath 'node'
```

Nothing else in the Node section changes — every use downstream (`$nodeExe`,
`Add-UserPath $nodeDir`, the corepack calls, the `.old` swap) already goes through
`$nodeDir`.

- [ ] **Step 2: Update `apps/README.md` § Node**

Replace lines 265-266:

```markdown
Node does **not** come from winget. It lives in the tree rather than Program Files, at the
path `layout/LAYOUT.md` declares for it, and `install.ps1` pulls the official zip and unpacks
it there.

It's in `dev\` and not `apps\` because you never open it — your projects invoke it.
`layout/LAYOUT.md` § *Which folder* is where that question is settled.
```

The path itself is deliberately not repeated here: `LAYOUT.md` is the place it's written
down, and a copy in this file is a copy that can go stale.

- [ ] **Step 3: Dry run and confirm the resolved path**

Run:

```powershell
pwsh apps\install.ps1 -WhatIfOnly
```

Expected, in the `=== Node` section — the new path, not `C:\Briar\Code\Node`:

```
  would  download Node vXX.XX.X (~100 MB) and unpack it into C:\Briar\dev\node
```

- [ ] **Step 4: Verify the real move**

Node currently lives at `C:\Briar\Code\Node`, so the real run **downloads a fresh copy** into
`C:\Briar\dev\node` rather than moving the old one. That is correct — this repo installs
latest stable from the vendor and never relocates what it finds.

```powershell
pwsh apps\install.ps1
pwsh -NoProfile -Command "& C:\Briar\dev\node\node.exe --version; [Environment]::GetEnvironmentVariable('Path','User') -split ';' | Where-Object { `$_ -match 'node' }"
```

Expected: the LTS version string, and `C:\Briar\dev\node` on the user PATH.

> The old `C:\Briar\Code\Node` is **left in place**. Deleting it is the format's job, and
> removing a working Node from a machine mid-plan is not this task's business.

- [ ] **Step 5: Run again — idempotency**

```powershell
pwsh apps\install.ps1
```

Expected: `[skip] Node vXX.XX.X (latest LTS)` and `[skip] PATH already has C:\Briar\dev\node`.

- [ ] **Step 6: Commit**

```bash
git add apps/install.ps1 apps/README.md
git commit -m "refactor: Node's path comes from LAYOUT.md instead of a literal"
```

---

### Task 6: Steam and League land in `games\`

**Files:**
- Modify: `_lib.ps1` (`Install-WingetPackage`, around line 79), `apps/install.ps1` (the
  winget install loop), `apps/README.md:113-118` and § *Manual afterwards*

**Interfaces:**
- Consumes: `Get-LayoutPath -IfDeclared` (Task 1).
- Produces: `Install-WingetPackage -Id <string> [-Location <string>]` → `'skip' | 'ok' |
  'fail'`, unchanged for callers that pass no location.

**The honest state of this task:** `winget --location` on Steam is **unverified**. Steam's
manifest is `nullsoft` and winget translates `--location` to NSIS `/D=` for that type, so it
should work — but installing Steam to find out was not worth it before a format. The code
below therefore treats the flag as something that can be rejected, and falls back rather
than failing the run.

League is different and not a gap to close: Riot ships a plain `exe` bootstrapper that asks
for the path interactively, and the 43 GB download happens after that regardless. So winget
still installs it and the user answers one prompt — which is why it stays in the automated
table with a note, rather than being demoted to a manual install.

- [ ] **Step 1: Teach `Install-WingetPackage` about `--location`**

Replace the body of `Install-WingetPackage` in `_lib.ps1`:

```powershell
# Returns 'skip', 'ok' or 'fail' rather than a boolean, so a caller can tell "was already
# there" apart from "installed it just now" without asking winget a second time. Knowing
# which is which is what lets the reboot warning fire only when it's actually earned.
#
# -Location comes from layout\LAYOUT.md and is best-effort on purpose. Not every installer
# accepts it - winget can only pass it on to installer types that declare a switch for it -
# and a package landing in its default folder is a far better outcome than a restore that
# stops. So a rejected location is retried without one and reported, never fatal.
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Location
    )
    if (Test-WingetInstalled $Id) { Write-Skip "$Id already installed"; return 'skip' }
    # 'ok' rather than 'skip': the caller uses that to mean "this run put it there", which
    # is what a dry run is claiming would happen. Reporting 'skip' made the upgrade pass
    # then ask winget about a package that isn't installed, and get told it was up to date.
    if ($script:DryRun) {
        Write-Would "install $Id$(if ($Location) { " into $Location" })"
        return 'ok'
    }

    Write-Host "  ...installing $Id$(if ($Location) { " -> $Location" })" -ForegroundColor DarkYellow
    $common = @('--exact', '--silent', '--accept-package-agreements',
        '--accept-source-agreements', '--disable-interactivity')

    $argv = @('install', '--id', $Id) + $common
    if ($Location) { $argv += @('--location', $Location) }
    & winget @argv 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -ne 0 -and $Location) {
        Write-Warn2 "$Id rejected --location (exit $LASTEXITCODE) - retrying at its default path"
        & winget @(@('install', '--id', $Id) + $common) 2>&1 |
            Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -eq 0) {
            Write-Warn2 "$Id installed, but NOT at $Location - update layout\LAYOUT.md or move it by hand"
            return 'ok'
        }
    }

    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id$(if ($Location) { " at $Location" })"; return 'ok' }
    Write-Warn2 "$Id exited with code $LASTEXITCODE"
    return 'fail'
}
```

- [ ] **Step 2: Pass the location from `apps/install.ps1`**

`apps/install.ps1:85-86` is currently:

```powershell
foreach ($id in $targets) {
    switch (Install-WingetPackage $id) {
```

Change it to look the ID up first:

```powershell
foreach ($id in $targets) {
    # A package only gets a location if LAYOUT.md declares one, which is almost none of them.
    # The vendor default is the right answer unless there's a reason, and LAYOUT.md is where
    # the reasons are written down - so -IfDeclared, and $null is the expected answer.
    $dest = Get-LayoutPath -Key $id -IfDeclared
    $outcome = if ($dest) { Install-WingetPackage -Id $id -Location $dest }
    else { Install-WingetPackage -Id $id }

    switch ($outcome) {
```

The rest of the `switch` body is untouched — the three return values are unchanged.

- [ ] **Step 3: Update the Games table in `apps/README.md`**

```markdown
| `Valve.Steam`                   | Steam             | Also a **dependency**: Wallpaper Engine is sold only through it. Installed into `games\` — see `layout/LAYOUT.md` |
| `RiotGames.LeagueOfLegends.LA2` | League of Legends | **LA2 = LAS**, the Latin America South server. Its installer asks where to put it |
```

- [ ] **Step 4: Add the League row to § Manual afterwards**

That section is read out loud at the end of a run, which is the only reason a prompt the user
has to answer correctly won't be missed.

`## Manual afterwards` holds **two** tables. The first is *"winget can't deliver them"* —
wrong for League, which winget delivers fine. The row goes in the second, *"Also by hand, for
reasons that have nothing to do with winget"*, at `apps/README.md:207-210`, whose columns are
`| What | Why |`:

```markdown
| **League's install path** | winget runs Riot's installer and it asks where to put the game. Answer with the `RiotGames.LeagueOfLegends.LA2` path in `layout/LAYOUT.md` — accepting the default puts 43 GB outside the tree and nothing later corrects it |
```

`Get-RowsFromReadme` reads both tables under that heading, so a row in either one reaches the
end-of-run report.

- [ ] **Step 5: Dry run**

```powershell
pwsh apps\install.ps1 -WhatIfOnly
```

Expected — a location on exactly two lines and no others:

```
  would  install Valve.Steam into C:\Briar\games\Steam
  would  install RiotGames.LeagueOfLegends.LA2 into C:\Briar\games\Riot Games
```

**Check no other package picked one up.** Every other ID must print the plain
`would install <id>` form; a location appearing on Git or Chrome means `-IfDeclared` is
matching too loosely.

- [ ] **Step 6: Verify the manual list still prints**

```powershell
pwsh apps\install.ps1 -WhatIfOnly 2>&1 | Select-String -Pattern 'League' -Context 0,1
```

Expected: the new Manual-afterwards row appears in the run's output. `CLAUDE.md` is explicit
that this list is not a footnote — if the row is in the file but not in the output, the
section name doesn't match what `Get-RowsFromReadme` is given and the row is invisible.

- [ ] **Step 7: Commit**

```bash
git add _lib.ps1 apps/install.ps1 apps/README.md
git commit -m "feat: install Steam and League into the games folder"
```

> **Not verifiable before the format.** Steam is already installed on this machine, so a real
> run reports `[skip]` and never exercises `--location`. The first true test is the restore.
> Say so in the final report rather than implying it was tested.

---

### Task 7: make the repo describe itself correctly

The last place the old tree still exists is the documentation, and `CLAUDE.md` is read by
every agent that opens this repo — a stale path table there is worse than no table.

**Files:**
- Create: `layout/README.md`
- Modify: `README.md` (§ The folders, § Install order, § Status), `CLAUDE.md:70-90`

- [ ] **Step 1: Write `layout/README.md`**

````markdown
# Layout

The folder tree the machine keeps, and the one place its paths are written down.

`LAYOUT.md` is the source. This file explains it; the scripts read it.

---

## `install.ps1`

```powershell
pwsh layout\install.ps1
pwsh layout\install.ps1 -WhatIfOnly     # report every action, perform none
```

Two steps: create the folders, then fix the root's permissions.

**It runs first.** `apps/` unpacks Node inside the tree, so the tree has to exist before it.

Idempotent, and it exits 1 with a named list when something doesn't complete — the same
contract as `apps/` and `dev/`.

---

## Where the folders come from

Two sources, and neither is this file:

| Folder | Comes from |
| ------ | ---------- |
| `apps\`, `dev\`, `games\`, `repos\` | The rows in `LAYOUT.md` marked `Created = yes` |
| `repos\mine\`, `repos\external\`, … | One per `.md` in `dev/repos/`, named after the file |

The second one is why adding a category costs a single file: create `dev/repos/clients.md`
and `repos\clients\` appears on the next run, with the clones going into it. There is no
second place to register it, so there is no second place to forget.

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

So the script drops inheritance and re-grants SYSTEM, Administrators and you — landing on
the `%LOCALAPPDATA%\Programs` shape.

### Two things about that code that look wrong and aren't

**`icacls`, not `Set-Acl`.** `Set-Acl` cannot remove an inherited ACE. `RemoveAccessRule`
returns `$true`, `Set-Acl` raises nothing, and the entry is still there afterwards —
measured on this machine, twice. A permissions change that fails silently is worse than one
that doesn't run.

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
- **It doesn't decide where a program goes.** `LAYOUT.md` § *Which folder* does, in four
  rows, so the question is answered the same way twice.
````

- [ ] **Step 2: Update the root `README.md`**

Add `layout/` to § The folders, as the first row:

```markdown
| **`layout/`**   | Where things live on disk, and the permissions on it   | Almost never                                    |
```

Replace § Install order:

```
0. windows/  bootstrap   winget, if LTSC didn't bring it
1. layout/               the folder tree
2. apps/                 the binaries
3. terminal/             the look
4. dev/                  Git, repos
5. claude/               Claude Code
6. windows/  the rest    Explorer tweaks — restarts Explorer
```

And the sentence under it becomes:

```markdown
Layout first because `apps/` unpacks Node inside the tree and `dev/` clones into it, so both
need it to exist. Apps next because everything after it configures programs that have to be
there already. `windows/` is split: the winget bootstrap has to run before anything, the
Explorer tweaks run last because they restart Explorer.
```

Add a row to § Status:

```markdown
| `layout/`   | ✅   | —           | ✅ tested     | Creates the tree from `LAYOUT.md`; hardens the root |
```

- [ ] **Step 3: Replace the path section in `CLAUDE.md`**

Lines 70-90 currently describe `C:\Briar\Code\` and a "today vs after the restore" table.
That table's whole subject is a tree this plan replaces. Replace the section with:

````markdown
## Paths on this machine

**`layout/LAYOUT.md` is the only place a path under `C:\Briar\` is written down.** Don't
hardcode one anywhere else — ask for it:

```powershell
. "$PSScriptRoot\..\_lib.ps1"
$dir = Get-LayoutPath 'node'
```

Most programs are **not** in there and shouldn't be. The vendor default is the right answer
unless there's a reason, and `LAYOUT.md` holds both the exceptions and the reasons. Git, VS
Code, Docker, Chrome, PowerShell and the runtimes all go where winget puts them, so resolve
those at run time (`Get-Command git`) rather than assuming a path.

User-level config is separate from all of this and moves with the user, not the install: VS
Code always reads `%APPDATA%\Code\User`, git always reads `~/.gitconfig`.

> **Until the format, the old hand-made tree is still on disk** — `C:\Briar\Code\`,
> `Programas\`, `Pen\`, `Facultad\` and three empty folders, about 226 GB. It is not what
> this repo builds and nothing here maintains it. Root `README.md` § *Before you wipe* is the
> decision record.

**There is no local PHP/MySQL stack on this machine.** Don't write anything that assumes one.
````

- [ ] **Step 4: Verify every remaining `C:\Briar` literal is deliberate**

Run:

```powershell
pwsh -NoProfile -Command "Select-String -Path (Get-ChildItem . -Recurse -Include *.ps1,*.md -Exclude 'docs' | Where-Object { `$_.FullName -notmatch '\\\.git\\|\\docs\\' }) -Pattern 'C:\\\\Briar' | ForEach-Object { '{0}:{1}' -f `$_.Path.Replace(`$PWD.Path,''), `$_.LineNumber }"
```

Expected: hits in `layout/LAYOUT.md` only, plus prose mentions in `layout/README.md`,
`README.md` § *Before you wipe*, `CLAUDE.md` and `windows/*.md`. **No hits in any `.ps1`.**
A literal left in a script is the exact failure this plan exists to remove.

- [ ] **Step 5: Full dry run, end to end**

```powershell
pwsh layout\install.ps1 -WhatIfOnly
pwsh apps\install.ps1 -WhatIfOnly
pwsh dev\install.ps1 -WhatIfOnly
```

Expected: all three exit 0 and none of them prints `C:\Briar\Code`.

- [ ] **Step 6: Commit**

```bash
git add layout/README.md README.md CLAUDE.md
git commit -m "docs: layout/ joins the install order and owns every path under the tree"
```

---

## What this plan does not do

Stated so it isn't mistaken for an oversight:

| | Why |
| --- | --- |
| Move or delete the old tree | The format does that. Root `README.md` § *Before you wipe* is the decision record, and it was verified rather than assumed |
| Move the existing Desktop checkouts | Already pushed; the format removes them. `dev/install.ps1` clones fresh into `repos\mine\` |
| Delete the old `C:\Briar\Code\Node` | Same. Task 5 installs a fresh LTS into `dev\node\` and leaves the old one alone |
| Set an ACL on anything but the root | Inheritance carries it down. One ACL, one place |

## Still open after this plan

Carried from the spec's § 9 — unrelated to the layout, listed so it doesn't get lost:

- `claude/install.ps1` doesn't exist. When it applies `mcp.template.json` it will create
  **duplicate MCP servers** for `playwright`, `chrome-devtools` and `context7`, each of which
  is already an enabled plugin.
- The root `install.ps1` orchestrator doesn't exist. Adding `layout/` to the install order in
  `README.md` is a documentation change; nothing runs the folders in sequence yet.
- `snapshot.ps1` doesn't exist. Its scope is now just the npm globals.
- The live `~/.gitconfig` is 9 lines against this repo's 16 settings; it has never been
  applied.
- `windows/debloat.ps1`, deferred until LTSC is installed.
