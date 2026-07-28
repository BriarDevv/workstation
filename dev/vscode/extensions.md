# VS Code extensions

60 extensions, grouped by what they're for. `install.ps1` reads the IDs in `backticks` —
add a row and it gets installed on the next run.

Full install takes ~10 unattended minutes.

---

## Laravel / PHP

The heaviest group. If you stop working with Laravel, there are 12 extensions here to drop.

| ID                                          | What it does                                  |
| ------------------------------------------- | --------------------------------------------- |
| `bmewburn.vscode-intelephense-client`       | The PHP engine: completion, go-to-definition  |
| `onecentlin.laravel-extension-pack`         | Pack that pulls in several of the ones below  |
| `onecentlin.laravel-blade`                  | Blade syntax                                  |
| `onecentlin.laravel5-snippets`              | Snippets                                      |
| `shufo.vscode-blade-formatter`              | Formats Blade                                 |
| `ihunte.laravel-blade-wrapper`              | Wraps a selection in Blade directives         |
| `amiralizadeh9480.laravel-extra-intellisense` | Completes routes, views, configs             |
| `ryannaddy.laravel-artisan`                 | Artisan commands from the palette             |
| `codingyu.laravel-goto-view`                | Ctrl+click from `view('x')` to the file       |
| `glitchbl.laravel-create-view`              | Creates the missing view                      |
| `naoray.laravel-goto-components`            | Jump to Blade components                      |
| `pgl.laravel-jump-controller`               | From route to controller                      |

## Vue / Astro / frontend

| ID                                   | What it does                              |
| ------------------------------------ | ----------------------------------------- |
| `vue.volar`                          | Vue 3                                     |
| `volartools.volar-ai`                | Volar extras                              |
| `sdras.vue-vscode-snippets`          | Vue snippets                              |
| `astro-build.astro-vscode`           | Astro                                     |
| `bradlc.vscode-tailwindcss`          | Tailwind class completion                 |
| `ecmel.vscode-html-css`              | Completes CSS classes inside HTML         |
| `formulahendry.auto-rename-tag`      | Renames the closing tag automatically     |
| `xabikos.javascriptsnippets`         | JS snippets                               |
| `naumovs.color-highlight`            | Paints hex colors inline                  |
| `kisstkondoros.vscode-gutter-preview` | Image previews in the gutter             |
| `ritwickdey.liveserver`              | Dev server with reload                    |
| `techer.open-in-browser`             | Open the current file in a browser        |
| `celianriboulet.webvalidator`        | HTML/CSS validation                       |

## TypeScript

| ID                                | What it does                     |
| --------------------------------- | -------------------------------- |
| `ms-vscode.vscode-typescript-next` | TS nightly                      |
| `yoavbls.pretty-ts-errors`        | Makes type errors readable       |
| `usernamehw.errorlens`            | Shows the error on the same line |

## Python

| ID                            | What it does        |
| ----------------------------- | ------------------- |
| `ms-python.python`            | Base                |
| `ms-python.vscode-pylance`    | Language / types    |
| `ms-python.debugpy`           | Debugger            |
| `ms-python.vscode-python-envs` | Environment handling |

## Git

| ID                    | What it does                            |
| --------------------- | --------------------------------------- |
| `eamodio.gitlens`     | Inline blame, history, comparisons      |
| `mhutchie.git-graph`  | The branch graph                        |

## Docker and remote

| ID                                  | What it does                     |
| ----------------------------------- | -------------------------------- |
| `ms-azuretools.vscode-docker`       | Docker                           |
| `ms-azuretools.vscode-containers`   | Containers                       |
| `ms-vscode-remote.remote-containers` | Work inside a container         |
| `ms-vscode-remote.remote-wsl`       | Work inside WSL                  |

## APIs and databases

| ID                             | What it does                      |
| ------------------------------ | --------------------------------- |
| `postman.postman-for-vscode`   | Postman                           |
| `rangav.vscode-thunder-client` | Lightweight REST client           |
| `damms005.devdb`               | Browse the DB without leaving the editor |
| `cubewise.canvas`              | —                                 |

## AI and testing

| ID                       | What it does                     |
| ------------------------ | -------------------------------- |
| `anthropic.claude-code`  | Claude Code inside VS Code       |
| `ms-playwright.playwright` | Run and debug E2E tests        |

## Themes and icons

| ID                                    | What it does                        |
| ------------------------------------- | ----------------------------------- |
| `catppuccin.catppuccin-vsc`           | **Catppuccin Mocha** — active theme |
| `catppuccin.catppuccin-vsc-icons`     | Catppuccin icons                    |
| `pkief.material-icon-theme`           | Material icons (active per settings) |
| `fredrikaverpil.vscode-material-theme` | Material                           |
| `sldobri.bunker`                      | Theme                               |

## Utilities

| ID                                | What it does                                        |
| --------------------------------- | --------------------------------------------------- |
| `esbenp.prettier-vscode`          | Formatting. Wired per language in `settings.json`   |
| `editorconfig.editorconfig`       | Respects the repo's `.editorconfig`                 |
| `christian-kohler.path-intellisense` | File path completion                             |
| `gruntfuggly.todo-tree`           | Collects every TODO into one panel                  |
| `mikestead.dotenv`                | `.env` syntax                                       |
| `tomoki1207.pdf`                  | PDF viewer                                          |
| `jeff-hykin.polacode-2019`        | Pretty code screenshots                             |
| `samplavigne.p5-vscode`           | p5.js                                               |
| `ms-vscode.powershell`            | PowerShell                                          |
| `ms-vscode.vscode-speech`         | Voice dictation                                     |
| `ms-ceintl.vscode-language-pack-es` | VS Code in Spanish                                |
