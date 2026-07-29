# Layout

Everything the machine keeps lives under one root, and **this table is the only place any of
those paths is written down**. A script that needs one asks `Get-LayoutPath`; it never holds
a literal. Move a folder by editing a row here.

## Paths

| Key                             | Path                        | Created | What it is                                                    |
| ------------------------------- | --------------------------- | ------- | ------------------------------------------------------------- |
| `root`                          | `C:\Briar`                  | yes     | The root. Nothing loose at this level                          |
| `apps`                          | `C:\Briar\apps`             | yes     | A program you open, when it has no vendor default to respect   |
| `dev`                           | `C:\Briar\dev`              | yes     | A tool your projects invoke rather than you                    |
| `games`                         | `C:\Briar\games`            | yes     | Games and their launchers                                      |
| `repos`                         | `C:\Briar\repos`            | yes     | Your own code. One subfolder per list in `dev/repos/`          |
| `node`                          | `C:\Briar\dev\node`         | no      | `apps/install.ps1` unpacks the zip here                        |
| `Valve.Steam`                   | `C:\Briar\games\Steam`      | no      | `winget --location`                                            |
| `RiotGames.LeagueOfLegends.LA2` | `C:\Briar\games\Riot Games` | no      | Its installer asks — see `apps/README.md` § Manual afterwards   |

`Created = no` means something else puts it there, so creating it up front would only race
whatever does.

## Which folder

| Do you run it to… | Folder   |
| ----------------- | -------- |
| write code        | `dev\`   |
| use it            | `apps\`  |
| play              | `games\` |
| it is your code   | `repos\` |

Node is `dev\` because you never open it — your projects invoke it. The question has to be
written down or it gets answered differently each time, which is how one machine ends up with
two folders that do the same job.

## An empty folder is fine. An undocumented one is not

Every folder in the table is created by the restore whether or not anything occupies it yet,
so the slot is already there the day you need it. What makes that safe is the last column: an
empty folder that says what belongs in it reads as *nothing has needed this yet*, not as
*someone gave up*.

The rule both ways round:

- a folder in the table exists, empty or not;
- a folder **not** in the table shouldn't exist — it either earns a row or it goes.

Which makes the tree auditable: `dir C:\Briar` and the table must agree.

## What does not live here

If Windows already has a folder for it, use Windows'.

| Thing                       | Where                                              |
| --------------------------- | -------------------------------------------------- |
| Downloads, installers       | `Downloads`, deleted after use                      |
| Screenshots                 | `Pictures\Screenshots`                              |
| PDFs, receipts, loose files | `Documents`                                         |
| Afternoon experiments       | The Desktop, deliberately — created, then deleted   |
| A project's design files    | Inside that project's repo, versioned with it       |

A folder of yours that competes with one the system already provides always loses: programs
save to Windows', you save to yours, and the same kind of file ends up in two places.

Throwaway code that might survive goes straight into `repos\mine\` and gets deleted if it
doesn't earn its place.
