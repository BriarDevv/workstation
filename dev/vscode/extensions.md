# VS Code extensions

28 extensions, grouped by what they're for. `install.ps1` reads the IDs in `backticks` —
add a row and it gets installed on the next run.

> Trimmed from 60 to 28 on 2026-07-28. What came out is listed at the bottom, so nothing
> gets "helpfully" reinstalled later.

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

| ID                 | What it does                         |
| ------------------ | ------------------------------------ |
| `ms-python.python` | Interpreter selection, basic support |

> ⚠️ **Pylance and debugpy were removed.** Without Pylance there's no IntelliSense, no
> go-to-definition and no type checking; without debugpy there's no debugger.
> `ms-python.python` on its own is not much past syntax highlighting. If Python is still
> part of the work, put `ms-python.vscode-pylance` back.

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

## Removed 2026-07-28 — don't reinstall

**Laravel (11)** — `onecentlin.laravel-extension-pack`, `onecentlin.laravel-blade`,
`onecentlin.laravel5-snippets`, `shufo.vscode-blade-formatter`,
`ihunte.laravel-blade-wrapper`, `amiralizadeh9480.laravel-extra-intellisense`,
`ryannaddy.laravel-artisan`, `codingyu.laravel-goto-view`, `glitchbl.laravel-create-view`,
`naoray.laravel-goto-components`, `pgl.laravel-jump-controller`

**Python (3)** — `ms-python.vscode-pylance`, `ms-python.debugpy`,
`ms-python.vscode-python-envs`

**Frontend (5)** — `sdras.vue-vscode-snippets`, `volartools.volar-ai`,
`celianriboulet.webvalidator`, `ritwickdey.liveserver`, `techer.open-in-browser`

**Tooling (7)** — `anthropic.claude-code`, `ms-playwright.playwright`,
`rangav.vscode-thunder-client`, `damms005.devdb`, `cubewise.canvas`,
`editorconfig.editorconfig`, `mikestead.dotenv`

**Misc (5)** — `gruntfuggly.todo-tree`, `jeff-hykin.polacode-2019`,
`samplavigne.p5-vscode`, `ms-vscode.vscode-speech`, `ms-ceintl.vscode-language-pack-es`

**Themes (1)** — `sldobri.bunker`

Removing `anthropic.claude-code` is deliberate, not an oversight: Claude Code runs from the
terminal here. See `../../claude/`.

---

## Settings with no owner left

These keys are still in `settings.json` and now do nothing:

| Key                                     | Extension it needed                  |
| --------------------------------------- | ------------------------------------ |
| `claudeCode.useTerminal`                | `anthropic.claude-code`              |
| `workbench.settings.applyToAllProfiles` | same                                 |
| `liveServer.settings.*`                 | `ritwickdey.liveserver`              |
| `github.copilot.*` (7 keys)             | Copilot — **never installed at all** |
| `chat.tools.terminal.autoApprove`       | same                                 |
| `chat.instructionsFilesLocations`       | same                                 |

Harmless — VS Code ignores settings with no owner. Listed so nobody spends an afternoon
wondering why they do nothing.

The Copilot ones are worth knowing about: **no Copilot is installed**, not as an extension
and not bundled with VS Code. Verified against `resources\app\extensions` and
`~\.vscode\extensions` — nothing matching. So `chat.tools.terminal.autoApprove`, which
auto-approves `npx`, `docker exec` and `docker-compose`, has nothing to auto-approve. It
was never the risk it looked like.
