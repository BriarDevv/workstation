# Terminal

How the terminal looks and feels. Config only — the programs (Windows Terminal, fastfetch,
the font) come from `apps/`.

**Nothing here is edited in place.** The look is composed at install time, so trying
something new means adding a file, not overwriting the thing that already works.

```
terminal/
├── style.json          ← which style is active
├── styles/             ← ONE FILE = ONE COMPLETE LOOK
│   └── catppuccin-mocha.json   (active)
├── schemes/            ← Windows Terminal color schemes, one file each
│   └── catppuccin-mocha.json
├── ascii-arts/         ← fastfetch logos
├── windows-terminal/   ← base settings: profiles, keybindings, everything else
├── powershell/         ← profile.ps1
└── install.ps1
```

**A style owns the entire look**: the font, the color scheme, the transparency, the ASCII
art, and every line the fetch prints when you open a terminal — which modules, their Nerd
Font glyphs, their colors, their order. Everything you see on that startup screen lives in
that one file.

What a style never contains: profiles, keybindings, anything structural. Those live in
`windows-terminal/settings.json`, written once.

There's no `fastfetch/config.jsonc` in the repo — it's **generated** from the style on
every install, so there is exactly one place to edit and nothing to keep in sync.

One style and one scheme right now, on purpose — Catppuccin Mocha, which is what the
fastfetch palette had always been anyway. The structure exists so a second look is a file
copy rather than a rewrite; see below.

---

## Everyday use

```powershell
pwsh terminal\install.ps1 -List                     # what's available
pwsh terminal\install.ps1                           # apply the active style
pwsh terminal\install.ps1 -Style catppuccin-mocha   # apply a specific one
```

Switching writes the new name into `style.json`, so the repo always says what's actually
on the machine. Switching back is the same command — the old style was never touched.

`-List` also prints every monospaced Nerd Font installed on this machine, which is the
list you can legally put in a style's `font.family`.

---

## Trying a new look

### A new style

```powershell
pwsh terminal\install.ps1 -NewStyle tokyo-night   # scaffolds from the active style
# edit terminal\styles\tokyo-night.json
pwsh terminal\install.ps1 -Style tokyo-night
```

`-NewStyle` copies the active style, blanks the description, and stops. Nothing on the
machine changes until you apply it. It refuses duplicate names and anything that isn't
lowercase kebab-case.

What a style holds:

| Key                     | What it does                                             |
| ----------------------- | -------------------------------------------------------- |
| `font.family`           | Must be a family Windows actually registered — see below  |
| `font.size` / `weight`  | `normal`, `medium`, `bold`, `extra-black`…               |
| `font.cellHeight`       | Line height (`"1.2"`)                                    |
| `terminal.colorScheme`  | Name of a scheme in `schemes/`                           |
| `terminal.opacity`      | 0–100                                                     |
| `terminal.useAcrylic`   | Blur behind the window                                   |
| `terminal.padding`      | `"8"`, or `"8, 8, 8, 8"`                                 |
| `terminal.cursorShape`  | `bar`, `filledBox`, `underscore`…                        |
| `fastfetch.asciiArt`    | Filename from `ascii-arts/`                              |
| `fastfetch.logoColors`  | The nine `$1`…`$9` color slots in the art                |
| `fastfetch.logoPadding` | Gap between art and text                                 |
| `fastfetch.display`     | Separator between key and value                          |
| `fastfetch.modules`     | **The startup screen** — see below                       |

Anything under `terminal.*` is copied straight into `profiles.defaults`, so **any**
Windows Terminal profile key works there, not just the ones listed.

### The startup screen

`fastfetch.modules` is the fetch, in fastfetch's own syntax. Reorder, delete, add:

```jsonc
"modules": [
  "break",                                              // blank line
  { "type": "title", "color": { "user": "#F5C2E7", "at": "#CDD6F4", "host": "#89DCEB" } },
  "break",
  { "type": "os",     "key": "",  "keyColor": "#89DCEB" },
  { "type": "cpu",    "key": "",  "keyColor": "#F5C2E7" },
  { "type": "board",  "key": "󰚗", "keyColor": "#FAB387" },
  { "type": "memory", "key": "",  "keyColor": "#A6E3A1", "format": "{used} / {total} ({percentage})" },
  { "type": "disk",   "key": "",  "keyColor": "#94E2D5" },
  "break",
  { "type": "colors", "symbol": "circle" }
]
```

Current set: `title`, `os`, `cpu`, `board`, `memory`, `disk`, `colors`.

`key` is the Nerd Font glyph shown before the value — grab more from
[nerdfonts.com/cheat-sheet](https://www.nerdfonts.com/cheat-sheet). Useful types fastfetch
supports that aren't in here: `gpu`, `uptime`, `shell`, `terminal`, `wm`, `packages`,
`localip`, `battery`, `datetime`.

> The install writes these glyphs unescaped, so the generated config stays readable. If
> you ever open it and see `` instead of a glyph, something re-encoded the file.

### A new color scheme

Drop a JSON file in `schemes/`. One object, exactly the shape Windows Terminal expects
(grab one from [windowsterminalthemes.dev](https://windowsterminalthemes.dev)):

```json
{ "name": "Tokyo Night", "background": "#1A1B26", "foreground": "#A9B1D6", ... }
```

Then reference it by `name` from a style. All of `schemes/` is merged into `settings.json`
on every install, so the scheme shows up in Windows Terminal's dropdown even if no style
uses it yet.

The install validates before writing: unknown scheme, missing ASCII art, unresolvable font
or empty `modules` all stop with a clear message instead of half-applying.

### New ASCII art

Drop a `.txt` in `ascii-arts/` and point a style's `fastfetch.asciiArt` at it.

The `$1`…`$9` markers inside are color slots that map to `logoColors`. Numbering the files
is cosmetic — fastfetch resolves by filename.

> These stay `.txt` on purpose: fastfetch reads them **raw**. Convert one to `.md` and the
> drawing breaks. They're assets, not documentation.

### A new font

Install it, then check the name Windows actually registered:

```powershell
pwsh terminal\install.ps1 -List
```

Put that exact string in `font.family`. Read the next section before you trust any name.

---

## Font names lie

Nerd Fonts ships two naming schemes for the same font, and winget's package has switched
between them:

| Registered name      | Variant             | Use for                                 |
| -------------------- | ------------------- | --------------------------------------- |
| `JetBrainsMono NF`   | Nerd Font           | wide glyphs, spills out of the cell      |
| `JetBrainsMono NFM`  | Nerd Font **Mono**  | ✅ terminals — glyphs stay in one cell   |
| `JetBrainsMono NFP`  | Nerd Font Propo     | proportional                            |

The long form `JetBrainsMono Nerd Font Mono` **does not exist** on this machine. Verified:

```
JetBrainsMono Nerd Font Mono     NO
JetBrainsMono NFM                YES
```

This config used to ask for the long name. Windows Terminal couldn't resolve it, silently
fell back to a default font, and filled the missing glyphs from another Nerd Font family
that happened to be on the machine. It looked close enough that nobody noticed for months —
which is the whole danger: the failure mode is "slightly wrong", not "broken".

**`install.ps1` now guards against this.** If a style names a font that isn't registered,
it looks for the Mono variant of the same family and uses that, telling you what it
substituted. If nothing matches it stops rather than leaving you with hollow boxes.

---

## Keep Windows Terminal on the latest version — not optional

**Windows Terminal ignores settings keys it doesn't recognise, and never tells you.**
No error, no warning. It loads the file, drops what it's too old to understand, and
renders with defaults.

This config depends on keys added fairly recently:

| Key                  | What it does                            |
| -------------------- | --------------------------------------- |
| `font.builtinGlyphs` | Sharp box-drawing and block characters  |
| `font.colorGlyphs`   | Color emoji and glyphs                  |
| `font.cellHeight`    | Line height — the spacing you like      |

On an older build the terminal opens perfectly happily and just looks *slightly wrong*.
Tighter line spacing, boxes a bit off. Nothing points at the version. You'll spend an hour
blaming the color scheme.

Same for **fastfetch**: the logo color slots and module keys have changed shape across
releases. An old binary reading a new `config.jsonc` drops what it can't parse and shows a
plain, colorless fetch.

`install.ps1` upgrades both on every run. `-SkipUpgrade` only when offline or deliberately
pinned.

### Manual check

```powershell
winget upgrade                              # what's outdated
winget upgrade --all --include-unknown      # update everything
```

**Pending as of 2026-07-27:**

| Package                   | Installed | Available |
| ------------------------- | --------- | --------- |
| `Fastfetch-cli.Fastfetch` | 2.58.0    | 2.66.0    |
| `Microsoft.PowerShell`    | 7.6.3.0   | 7.6.4.0   |

> `winget upgrade --all` also updates Windows Terminal, which rewrites its `settings.json`.
> Re-run `install.ps1` afterwards to put your style back.

---

## `powershell/profile.ps1`

Runs on every new shell. Two things:

**1. A `claude` wrapper** injecting default flags:

```powershell
function claude { & claude.exe --effort xhigh --dangerously-skip-permissions @args }
```

> ⚠️ `--dangerously-skip-permissions` runs **everything** without asking, and **overrides**
> whatever `defaultMode` you set in `claude/settings.json` — configure `auto` there and this
> flag still bypasses it. It also contradicts your own rule in
> `claude/rules/common/hooks.md` ("Never use dangerously-skip-permissions flag"). Left as-is
> because it's your call, but to tighten up: drop the flag here first, then set
> `defaultMode: "auto"`.

**2. fastfetch on startup**, guarded to interactive consoles only. The `if` checks that
stdin/stdout aren't redirected, so it never pollutes piped or scripted output.

---

## What `install.ps1` does

1. **Resolves the style** — `-Style`, or `active` from `style.json`.
2. **Validates the font** and repairs the name if the registered one differs.
3. **Upgrades** Windows Terminal and fastfetch.
4. **Composes `settings.json`** — base + every scheme in `schemes/` + the style's knobs.
5. **Generates `config.jsonc`** entirely from the style — logo, colors, and the module list
   that makes up the startup screen. The logo path is rewritten to the real `$HOME`, so the
   repo survives a different Windows username. Nerd Font glyphs are written unescaped.
6. **Copies** the ASCII art and the PowerShell profile.
7. **Records** the active style back into `style.json`.

Everything it overwrites is backed up to `$HOME\.workstation-backup\<date>\`. It only
writes into Windows Terminal folders that already exist. Running it twice is a no-op —
every step reports `[skip]` when nothing changed.

`-SyncEditorFont` also writes the style's font into `dev/vscode/settings.json`, so the
editor matches the terminal.

---

## Verified 2026-07-27

- Compose preserved all 5 Windows Terminal profiles and both glyph keys
- Round-trip across three styles returned byte-identical settings, so switching is lossless
- Second run: all `[skip]`
- `fastfetch` renders `02-purin-face.txt` with the Catppuccin palette and Nerd Font glyphs
- After the scheme cleanup: 1 scheme merged, no profile left pointing at a deleted one

Applied state:

| | |
| --- | --- |
| Style | `catppuccin-mocha` |
| Font | JetBrainsMono NFM, 10pt, extra-black, cellHeight 1.2 |
| Window | opacity 70, acrylic, padding 8, filledBox cursor |
| Logo | `02-purin-face.txt` |
