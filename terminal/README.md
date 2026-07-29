# Terminal

This folder composes the visual terminal configuration. Windows Terminal, fastfetch, and
the Nerd Font are installed by `apps/`; this folder owns their user configuration.

```text
terminal/
├── style.json                active style name
├── styles/*.json             complete visual styles
├── schemes/*.json            Windows Terminal color schemes
├── ascii-arts/*.txt          raw fastfetch assets
├── windows-terminal/         structural base settings
├── powershell/profile.ps1    interactive shell profile
└── install.ps1               validator and composer
```

The Windows Terminal output is base settings + every scheme + the selected style's terminal
and font fields. Fastfetch `config.jsonc` is generated entirely from the style. There is no
repo copy of that generated file.

## Commands

```powershell
pwsh terminal\install.ps1 -List
pwsh terminal\install.ps1
pwsh terminal\install.ps1 -Style catppuccin-mocha
pwsh terminal\install.ps1 -WhatIfOnly
pwsh terminal\install.ps1 -Style catppuccin-mocha -SyncEditorFont
pwsh terminal\install.ps1 -NewStyle tokyo-night
```

`-WhatIfOnly` performs composition and validation but writes no machine or repository files.
`-NewStyle` also honors it. Applying a named style records that choice in `style.json`.
`-SyncEditorFont` updates or creates the two font keys in the current user's live VS Code
settings; every unrelated editor setting remains untouched and owned by Settings Sync.

## Style fields

| Key | Meaning |
| --- | --- |
| `font.family`, `size`, `weight`, `cellHeight` | Registered Windows font and metrics |
| `terminal.colorScheme` | A scheme name present in `schemes/` |
| `terminal.opacity`, `useAcrylic`, `padding`, `cursorShape` | Profile defaults |
| `fastfetch.asciiArt` | A filename in `ascii-arts/` |
| `fastfetch.logoColors`, `logoPadding`, `display` | Logo and value presentation |
| `fastfetch.modules` | Complete startup module list |

Other valid Windows Terminal profile-default keys can live under `terminal`. Structural
state such as profiles, keybindings, and tab behavior belongs in
`windows-terminal/settings.json` instead.

To add a look, scaffold it from the active style, edit the resulting JSON, add any required
scheme or ASCII asset, then apply it. The installer rejects an unknown scheme, missing art,
empty module list, or unresolved font before writing outputs.

## Fonts

Use the exact family name registered by Windows:

```powershell
pwsh terminal\install.ps1 -List
```

Nerd Fonts may register a mono family with a compact `NFM` suffix or a longer `Nerd Font
Mono` name. The installer resolves the exact requested name first, then the equivalent mono
variant. It stops if neither exists; Windows Terminal's silent fallback would otherwise
make the configuration appear valid while rendering the wrong font.

## Generated outputs

The installer:

1. resolves and validates the style;
2. checks updates for Windows Terminal and fastfetch unless `-SkipUpgrade` is used;
3. composes Windows Terminal settings only for installed Terminal variants;
4. generates fastfetch config and copies raw ASCII assets;
5. installs the PowerShell profile;
6. optionally updates the live VS Code font; and
7. records a newly selected active style.

Every replaced user file uses the shared run-scoped backup and atomic text writer. A failed
upgrade or write makes the script exit non-zero.

## PowerShell profile

The profile runs fastfetch only in an interactive console and defines the deliberate Claude
wrapper:

```powershell
function claude { & claude.exe --effort xhigh --dangerously-skip-permissions @args }
```

That flag bypasses Claude's permission prompts even though `claude/settings.json` uses a
safer default for launches outside this profile. It is intentionally retained as requested.

The `.txt` files in `ascii-arts/` are assets read verbatim by fastfetch. Do not reformat or
convert them to Markdown.
