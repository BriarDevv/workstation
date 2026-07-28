# Repos to clone

Which repositories land on this machine, and where.

> **This file ages faster than anything else in the repo.** Apps change once a year;
> which projects you're working on changes every few months. Treat a stale row here as
> normal, not as a bug — and don't let anything else grow a dependency on this list.

It's kept separate from `README.md` on purpose. `README.md` describes the **machine**;
this describes the **work**, and the two move at completely different speeds.

The line the repo holds: it can say **where your code goes, never how your projects work**.
No build steps, no run instructions, no per-project stack notes. Those belong to the
project, not to the machine.

---

## The list

| Repo                     | Remote                               | Destination          |
| ------------------------ | ------------------------------------ | -------------------- |
| Bystellabotella          | `BriarDevv/Bystellabotella`          | `~\Desktop\`         |
| Portafolio               | `BriarDevv/Portafolio`               | `~\Desktop\`         |
| Ynara                    | `BriarDevv/Ynara`                    | `~\Desktop\`         |
| EDocente                 | `BriarDevv/Empoderamiento-Docente`   | `~\Desktop\EDocente` |
| Inferiores-Riverplatense | `BriarDevv/Inferiores-riverplatense` | `~\Desktop\`         |
| KioscoDiagonal           | `BriarDevv/Kiosco-Diagonal`          | `~\Desktop\`         |
| LaBoutique               | `Gaston3000/laboutique`              | `~\Desktop\`         |

Cloning needs `gh auth login` done first.

> For whoever writes the parser: this table is **not** shaped like the ones in
> `apps/README.md`. There the ID is a single backticked value in column 1, which is all
> `Get-IdsFromReadme` knows how to read. Here the useful columns are 2 and 3, and column 1
> is plain text. It needs its own reader.

Two rows carry a decision rather than just a name, which is why the table exists at all
instead of a `gh repo list`:

- **EDocente** is checked out under a shorter local name than its remote.
- **LaBoutique** isn't yours — it's `Gaston3000/laboutique`, so it would never show up in
  a listing of your own repos.

Everything is cloned to the Desktop and nothing else happens to it — no symlinks, no
per-project setup. There's no local PHP/MySQL stack on this machine, so nothing here serves
anything.

---

## Not on any remote

See the root `README.md` § **Before you wipe** — those folders exist only on this disk and
nothing here clones them.
