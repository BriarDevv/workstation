# VS Code extensions

31 extensions, grouped by what they're for. `install.ps1` reads the IDs in `backticks` —
add a row and it gets installed on the next run.

> **This table is the whole list.** It was cut from 60 to 31 on 2026-07-28; what isn't here
> isn't wanted, and that includes anything a previous version of this file used to mention.

---

## Frontend

| ID                                    | What it does                          |
| ------------------------------------- | ------------------------------------- |
| `vue.volar`                           | Vue 3                                 |
| `astro-build.astro-vscode`            | Astro                                 |
| `bradlc.vscode-tailwindcss`           | Tailwind class completion             |
| `ecmel.vscode-html-css`               | Completes CSS classes inside HTML     |
| `formulahendry.auto-rename-tag`       | Renames the closing tag automatically |
| `xabikos.javascriptsnippets`          | JS snippets                           |
| `naumovs.color-highlight`             | Paints hex colors inline              |
| `kisstkondoros.vscode-gutter-preview` | Image previews in the gutter          |

## TypeScript

| ID                                 | What it does                     |
| ---------------------------------- | -------------------------------- |
| `ms-vscode.vscode-typescript-next` | TS nightly                       |
| `yoavbls.pretty-ts-errors`         | Makes type errors readable       |
| `usernamehw.errorlens`             | Shows the error on the same line |

## PHP

| ID                                    | What it does                             |
| ------------------------------------- | ---------------------------------------- |
| `bmewburn.vscode-intelephense-client` | PHP engine: completion, go-to-definition |

The twelve Laravel-specific helpers came out. Intelephense stays, so plain PHP still
works — only the Blade/artisan/route sugar is gone.

## Python

| ID                             | What it does                       |
| ------------------------------ | ---------------------------------- |
| `ms-python.python`             | Interpreter selection, base support |
| `ms-python.vscode-pylance`     | IntelliSense, go-to-definition, type checking |
| `ms-python.debugpy`            | Debugger                           |
| `ms-python.vscode-python-envs` | Environment management             |

These came out in the 2026-07-28 trim and went straight back in. **Ynara has a real Python
backend** — `apps/backend` with alembic migrations and a test suite covering `api`, `core`,
`integration`, `llm`, `memory`, `models`, last touched 2026-06-28. Without Pylance there's
no IntelliSense, no go-to-definition and no type checking on that project; without debugpy
there are no breakpoints. `ms-python.python` alone is barely past syntax highlighting.

`vscode-python-envs` came back on its own as a dependency.

## Git

| ID                   | What it does                       |
| -------------------- | ---------------------------------- |
| `eamodio.gitlens`    | Inline blame, history, comparisons |
| `mhutchie.git-graph` | The branch graph                   |

## Docker and remote

| ID                                   | What it does            |
| ------------------------------------ | ----------------------- |
| `ms-azuretools.vscode-docker`        | Docker                  |
| `ms-azuretools.vscode-containers`    | Containers              |
| `ms-vscode-remote.remote-containers` | Work inside a container |
| `ms-vscode-remote.remote-wsl`        | Work inside WSL         |

## APIs

| ID                           | What it does |
| ---------------------------- | ------------ |
| `postman.postman-for-vscode` | Postman      |

## Themes and icons

| ID                                     | What it does                         |
| -------------------------------------- | ------------------------------------ |
| `catppuccin.catppuccin-vsc`            | **Catppuccin Mocha** — active theme  |
| `catppuccin.catppuccin-vsc-icons`      | Catppuccin icons                     |
| `pkief.material-icon-theme`            | Material icons (active per settings) |
| `fredrikaverpil.vscode-material-theme` | Material                             |

## Utilities

| ID                                   | What it does                                      |
| ------------------------------------ | ------------------------------------------------- |
| `esbenp.prettier-vscode`             | Formatting. Wired per language in `settings.json` |
| `christian-kohler.path-intellisense` | File path completion                              |
| `ms-vscode.powershell`               | PowerShell                                        |
| `tomoki1207.pdf`                     | PDF viewer                                        |

---

## About `settings.json`

It was trimmed to 75 lines on 2026-07-28 so that every key in it belongs to an extension in
the table above. If you add an extension, its settings go there; if you drop one, take its
keys with it. A key with nothing behind it is dead weight that reads like configuration.
