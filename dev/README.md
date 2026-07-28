# Dev

The development environment: editor, git, and the repos to clone. The programs themselves
come from `apps/` — this folder only configures them.

---

## `vscode/`

| File               | What it is                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| `settings.json`    | Catppuccin Mocha, sidebar on the right, activity bar on top, no minimap, ruler at 120, Prettier per language   |
| `keybindings.json` | One binding: `Shift+Enter` in the terminal sends `ESC + CR` (newline without executing)                        |
| `extensions.md`    | The 28 extensions, grouped by what they're for, plus the 32 removed on 2026-07-28              |

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

### Dead settings

After the 2026-07-28 cleanup a handful of keys have no extension behind them any more —
`claudeCode.useTerminal`, `liveServer.settings.*`, and every `github.copilot.*` key.
Harmless, but `extensions.md` lists them so you don't go looking for why they do nothing.

Worth correcting an earlier note in this file: `chat.tools.terminal.autoApprove` looked
like a security hole because it auto-approves `npx`, `docker exec` and `docker-compose`.
**There is no Copilot installed on this machine** — not as an extension, not bundled with
VS Code — so there is nothing for it to auto-approve. Verified against
`resources\app\extensions` and `~\.vscode\extensions`.

There are also 18 `postman-*.instructions.md` paths in `chat.instructionsFilesLocations`
pointing at `%TEMP%` for three different users (`USER`, `mateo`, `Alumno`). Junk left
behind by the Postman extension. Safe to delete whenever.

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
| KioscoDiagonal           | `BriarDevv/Kiosco-Diagonal`          | `~\Desktop\`                             |
| LaBoutique               | `Gaston3000/laboutique`              | `~\Desktop\`                             |

Cloning needs `gh auth login` done first.

**KioscoDiagonal** used to get a **symlink** into `C:\Briar\Code\Laragon\www\`, so Laragon
could serve it while you edited the Desktop copy. Laragon was dropped from `apps/` on
2026-07-28, so the symlink went with it — the repo is cloned to the Desktop like every
other one and nothing serves it.

It's a PHP project, so **it has no way to run locally right now.** Intelephense still gives
you language support in the editor; there's just no PHP/MySQL stack behind it. If you pick
this project up again, the two realistic options are putting Laragon back (one row in
`apps/README.md`) or giving it a `docker-compose.yml`, since Docker is already installed.

> ⚠️ These folders are on **no remote** and are not cloned by anything:
> `C:\Briar\Facultad`, `C:\Briar\Trabajo`, `C:\Briar\WAND`, `C:\Briar\Pen`,
> `C:\Briar\Paginas`. Back them up manually before wiping the machine.
