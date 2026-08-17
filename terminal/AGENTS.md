# terminal

The live configuration is composed; never copy a live Windows Terminal
`settings.json` back over the repo base.

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

When syncing from the machine: compose the expected output, diff against
the live files, route only intentional differences (ignore defaults
Windows Terminal added by itself); ambiguous ownership → ask first.

Invariants: a style must reference an existing scheme; a declared
`fastfetch` block needs an existing ASCII asset and a non-empty module
list; font names must resolve to a registered mono family (Windows
silently falls back); the base profile resolves `pwsh.exe` through PATH.
