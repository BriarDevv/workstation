# VS Code extensions

Grouped by what they're for. `install.ps1` reads the IDs in `backticks` — add a row and it
gets installed on the next run.

> **This table is the whole list.** What isn't in it isn't wanted.

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

Intelephense on its own, which covers plain PHP. Nothing framework-specific.

## Python

| ID                             | What it does                       |
| ------------------------------ | ---------------------------------- |
| `ms-python.python`             | Interpreter selection, base support |
| `ms-python.vscode-pylance`     | IntelliSense, go-to-definition, type checking |
| `ms-python.debugpy`            | Debugger                           |
| `ms-python.vscode-python-envs` | Environment management             |

All four, not just `ms-python.python` — on its own that one is barely past syntax
highlighting. Pylance is what gives you IntelliSense, go-to-definition and type checking;
debugpy is what gives you breakpoints. `vscode-python-envs` arrives as a dependency.

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

Every key in it belongs to an extension in the table above. If you add an extension, its
settings go there; if you drop one, take its keys with it. A key with nothing behind it is
dead weight that reads like configuration.
