# VS Code extensions

31 extensions, grouped by what they're for. `install.ps1` reads the IDs in `backticks` —
add a row and it gets installed on the next run.

> Trimmed from 60 to 28 on 2026-07-28, then Python support went back in (31). What came out is listed at the bottom, so nothing
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

## Removed 2026-07-28 — don't reinstall

**Laravel (11)** — `onecentlin.laravel-extension-pack`, `onecentlin.laravel-blade`,
`onecentlin.laravel5-snippets`, `shufo.vscode-blade-formatter`,
`ihunte.laravel-blade-wrapper`, `amiralizadeh9480.laravel-extra-intellisense`,
`ryannaddy.laravel-artisan`, `codingyu.laravel-goto-view`, `glitchbl.laravel-create-view`,
`naoray.laravel-goto-components`, `pgl.laravel-jump-controller`

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

## Settings cleaned out at the same time

The trim left a pile of keys pointing at extensions that no longer existed. Those went too,
on 2026-07-28 — `settings.json` dropped from 145 lines to 75.

| Removed                                                 | Why                                     |
| -------------------------------------------------------- | --------------------------------------- |
| `claudeCode.useTerminal`, `workbench.settings.applyToAllProfiles` | `anthropic.claude-code` is gone |
| `liveServer.settings.*` (2 keys)                        | `ritwickdey.liveserver` is gone         |
| `github.copilot.*` (3 keys)                             | Copilot unused for ~6 months            |
| `chat.agent.maxRequests`, `chat.tools.terminal.autoApprove`, `chat.tools.urls.autoApprove` | Copilot chat surface, nothing behind it |
| `chat.instructionsFilesLocations`                       | 22 paths, 18 of them Postman junk under `%TEMP%` for three different users |
| `gitlens.ai.model`, `gitlens.ai.vscode.model`           | Pointed at `copilot:gpt-4.1`, which isn't installed. GitLens itself stays |
| `workbench.colorCustomizations`                         | An empty object. Did nothing            |

Worth recording, because it was on the list of things to worry about and turned out not to
be: **no Copilot was installed at all** — not as an extension, not bundled with VS Code.
Verified against `resources\app\extensions` and `~\.vscode\extensions`. So
`chat.tools.terminal.autoApprove`, which auto-approved `npx`, `docker exec` and
`docker-compose`, had nothing to auto-approve. It was never the hole it looked like.
