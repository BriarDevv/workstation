# terminal instructions

The live configuration is composed; never copy a live Windows Terminal `settings.json` back
over the repo base.

```text
windows-terminal/settings.json + schemes/*.json + styles/<active>.json
    -> live Windows Terminal settings.json

styles/<active>.json
    -> ~/.config/fastfetch/config.jsonc
```

Route changes by ownership:

| Change | Source file |
| --- | --- |
| Font, opacity, scheme choice, padding, cursor | `styles/<name>.json` |
| Fastfetch logo, colors, or modules | `styles/<name>.json` |
| Palette values | `schemes/<name>.json` |
| Profiles, keybindings, tabs, structure | `windows-terminal/settings.json` |
| Active style name | `style.json` |

When syncing from the machine, compose the expected output and diff it with the live files.
Route only intentional differences; ignore defaults that Windows Terminal added by itself.
If ownership is ambiguous, ask before flattening it into a layer.

Keep these invariants:

- `ascii-arts/*.txt` are raw assets; preserve whitespace and `$1`…`$9` color markers.
- A style must reference an existing scheme and ASCII asset and contain fastfetch modules.
- Font names must resolve to a registered mono family; Windows silently falls back.
- The base profile resolves `pwsh.exe` through PATH rather than assuming MSI paths.
- Default runs upgrade Windows Terminal and fastfetch; `-SkipUpgrade` stays opt-in.
- All writes use the shared backup/config helpers and remain idempotent.
- `-WhatIfOnly` must not modify live config or `style.json`.
- The Claude bypass flag in `powershell/profile.ps1` is deliberate and remains in place.
