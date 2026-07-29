# Repos

One `.md` per list. `install.ps1` reads **every file in this folder except this one**, so
adding a list means adding a file — there's nothing to register it in.

| File          | What's in it                          |
| ------------- | ------------------------------------- |
| `mine.md`     | The `BriarDevv` repos                 |
| `external.md` | Anyone else's. Empty, and that's fine |

Split them however you like — by owner, by client, by whether you actually work on them.
The script doesn't care what the files are called or how many there are.

> **This folder ages faster than anything else in the repo.** Apps change once a year;
> which projects you're working on changes every few months. A stale row here is normal
> rather than a bug — and nothing else should grow a dependency on these lists.

Kept out of `../README.md` on purpose: that file describes the **machine**, these describe
the **work**, and the two move at completely different speeds.

---

## The format

A file counts as a clone list when it has a `## The list` section holding a table:

| Column | What it is             |
| ------ | ---------------------- |
| 1      | The local folder name  |
| 2      | `owner/repo` on GitHub |

**Where they land comes from the file's own name.** `mine.md` clones into `repos\mine\`,
`external.md` into `repos\external\`, and the root of that comes from `layout/LAYOUT.md`.

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

---

## What doesn't go here

**Where your code lands, never how your projects work.** No build steps, no run
instructions, no per-project stack notes — those belong to the project itself. The root
`CLAUDE.md` states it as a hard rule: outside this folder, naming a project at all is a bug,
because the machine outlives every project on it.

> ⚠️ Some folders on this disk are on **no remote at all** and nothing here clones them.
> Root `README.md` § **Before you wipe** has the list.
