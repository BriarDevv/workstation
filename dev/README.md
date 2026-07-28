# Dev

The development environment: editor, git, and the repos to clone. The programs themselves
come from `apps/` — this folder only configures them.

---

## `vscode/`

| File               | What it is                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| `settings.json`    | Catppuccin Mocha, sidebar on the right, activity bar on top, no minimap, ruler at 120, Prettier per language   |
| `keybindings.json` | One binding: `Shift+Enter` in the terminal sends `ESC + CR` (newline without executing)                        |
| `extensions.md`    | All 60 extensions, grouped by what they're for                                                                 |

Installs to `%APPDATA%\Code\User\`.

### Font

`editor.fontFamily` and `terminal.integrated.fontFamily` are both `JetBrainsMono NFM`,
matching the terminal. That name is deliberate and not obvious — read
`../terminal/README.md` § "Font names lie" before changing it. The short version: Windows
falls back silently when a family name doesn't resolve, and the long form
`JetBrainsMono Nerd Font Mono` is not what winget registers.

VS Code had **no** `editor.fontFamily` at all until 2026-07-27, so it was running on
Consolas — which meant `editor.fontLigatures: true` did nothing, since Consolas has no
ligatures. Both are set now and the ligatures work.

`pwsh terminal\install.ps1 -SyncEditorFont` rewrites both keys from the active terminal
style, so the editor follows whatever font the terminal is using.

### Two things left as-is

> ⚠️ `chat.tools.terminal.autoApprove` has `npx`, `docker exec` and `docker-compose` set to
> `true`. That lets Copilot run those commands without asking. It's the same pattern we
> tightened on the Claude side, left alone here deliberately.

> There are 18 `postman-*.instructions.md` paths in `chat.instructionsFilesLocations`
> pointing at `%TEMP%` for three different users (`USER`, `mateo`, `Alumno`). Junk left
> behind by the Postman extension. Safe to delete whenever.

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
| `credential.helper`         | Delegates to `gh` — no tokens in the config file             |
| `init.defaultBranch = main` | —                                                            |
| `fetch.prune = true`        | Cleans up dead remote branches on fetch                      |

Aliases: `s` (short status), `lg` (graph log), `last`, `unstage`, `amend`.

**Manual afterwards:** `gh auth login` → account `BriarDevv`, HTTPS, scopes
`gist, read:org, repo, workflow`. There's no way to script an OAuth flow.

---

## Repos to clone

| Repo                     | Remote                               | Destination                              |
| ------------------------ | ------------------------------------ | ---------------------------------------- |
| Bystellabotella          | `BriarDevv/Bystellabotella`          | `~\Desktop\`                             |
| Portafolio               | `BriarDevv/Portafolio`               | `~\Desktop\`                             |
| Ynara                    | `BriarDevv/Ynara`                    | `~\Desktop\`                             |
| EDocente                 | `BriarDevv/Empoderamiento-Docente`   | `~\Desktop\EDocente`                     |
| Inferiores-Riverplatense | `BriarDevv/Inferiores-riverplatense` | `~\Desktop\`                             |
| KioscoDiagonal           | `BriarDevv/Kiosco-Diagonal`          | `~\Desktop\` + symlink in `Laragon\www\` |
| LaBoutique               | `Gaston3000/laboutique`              | `~\Desktop\`                             |

Cloning needs `gh auth login` done first.

**KioscoDiagonal** is served by Laragon from `C:\Briar\Code\Laragon\www\Kiosco-Diagonal`.
The install creates a **symlink** there pointing at the Desktop copy, so there's only one
working tree. Needs an elevated shell or Windows Developer Mode enabled.

> ⚠️ These folders are on **no remote** and are not cloned by anything:
> `C:\Briar\Facultad`, `C:\Briar\Trabajo`, `C:\Briar\WAND`, `C:\Briar\Pen`,
> `C:\Briar\Paginas`. Back them up manually before wiping the machine.
