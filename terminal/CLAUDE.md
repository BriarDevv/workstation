# terminal/ — instructions

Read this before changing anything in this folder. The usual request is:

> "I made a couple of styles and tweaked some settings on the machine — read the repo and
> bring it up to date."

That job is below under **Syncing the machine back into the repo**.

---

## The model

Nothing here is a copy of what's on the machine. The live config is **composed** at install
time:

```
windows-terminal/settings.json   base: profiles, keybindings, structure
  + schemes/*.json               all of them, merged into the schemes array
  + styles/<active>.json         font, colorScheme, opacity, padding, cursor
  ────────────────────────────▶  %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json

styles/<active>.json             logo, colors, module list
  ────────────────────────────▶  ~\.config\fastfetch\config.jsonc     (fully generated)
```

`style.json` holds one key: which style is active.

**There is no `fastfetch/config.jsonc` in the repo.** It's generated. If you find yourself
creating one, you've misunderstood the design.

---

## The rule that matters most

**Never write a live `settings.json` back into `windows-terminal/settings.json`.**

The live file is the *composed output*. Copying it back flattens schemes and style values
into the base, which destroys the style system — you end up with one big file again, which
is exactly what this structure exists to avoid.

When something changed on the machine, figure out **which layer it belongs to** and edit
that layer:

| What changed                                          | Where it goes                        |
| ----------------------------------------------------- | ------------------------------------ |
| Font family, size, weight, cellHeight                 | `styles/<name>.json` → `font`        |
| Color scheme name, opacity, acrylic, padding, cursor  | `styles/<name>.json` → `terminal`    |
| ASCII art choice, logo colors, fetch modules          | `styles/<name>.json` → `fastfetch`   |
| The colors *inside* a scheme                          | `schemes/<name>.json`                |
| Profiles, keybindings, tab behaviour, newTabMenu      | `windows-terminal/settings.json`     |
| Which style is active                                 | `style.json`                         |

If a value could plausibly belong to two layers, **ask** rather than guessing. Putting a
per-look value in the base means every future style inherits it silently.

---

## Syncing the machine back into the repo

1. **Read the live files.**
   - `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
   - `~\.config\fastfetch\config.jsonc`
   - `$PROFILE.CurrentUserCurrentHost`

2. **Compose what the repo *would* produce** for the active style, and diff against live.
   Only the differences matter — don't rewrite files that already agree.

3. **Route each difference** to its layer using the table above.

4. **Watch for keys Windows Terminal added on its own.** It writes new keys with default
   values after an upgrade. Those are noise, not intent — don't capture them just because
   they appeared. If a key looks new and no one asked for it, leave it out and mention it.

5. **New styles**: if the machine has a look that isn't in `styles/`, create the file with
   `install.ps1 -NewStyle <name>` and fill it in. Kebab-case names.

6. **Re-run `install.ps1`** and confirm every line reports `[skip]`. That's the proof the
   repo and the machine agree. If something still says `[ok]` with a backup warning, the
   sync is incomplete.

7. **Report** what moved to which layer, and anything you deliberately left out.

---

## Hard rules

**`ascii-arts/*.txt` are assets, not documentation.** fastfetch reads them raw. The `$1`…`$9`
markers are color slots. Don't convert them to `.md`, don't reformat them, don't "fix" the
whitespace.

**Fonts fail silently.** Windows falls back without any error when a family name doesn't
resolve. Before putting a font name in a style, confirm it's registered:

```powershell
Add-Type -AssemblyName System.Drawing
[System.Drawing.FontFamily]::Families.Name | Where-Object { $_ -match 'NFM|Nerd Font Mono' }
```

Nerd Fonts ships both `JetBrainsMono NFM` and `JetBrainsMono Nerd Font Mono` depending on
the release. This repo was shipping the second one for months while only the first was
installed. `install.ps1` now substitutes and warns, but don't rely on the safety net.

**A style must name a scheme that exists** in `schemes/`, and an `asciiArt` that exists in
`ascii-arts/`. `install.ps1` validates both and stops rather than half-applying.

**Scripts are idempotent.** Running twice reports `[skip]` everywhere. If a change breaks
that, the change is wrong.

**Everything overwritten is backed up** to `$HOME\.workstation-backup\<date>\` first. Keep
it that way.

---

## Keep Windows Terminal current

Windows Terminal **silently drops settings keys it doesn't recognise**. This config uses
`font.builtinGlyphs`, `font.colorGlyphs` and `font.cellHeight`, all recent additions — on
an old build the terminal opens fine and just renders wrong, with nothing pointing at the
version. Same for fastfetch and its logo color slots.

`install.ps1` upgrades both on every run. Don't add `-SkipUpgrade` to any default path.

---

## Deliberate omissions

Don't "helpfully" re-add these:

- **Oh My Posh** — removed 2026-07-27. Was installed for months but never initialised in
  the profile, so the prompt stayed plain PowerShell. Not wanted.
- **Warp** — removed 2026-07-27, not used any more.
- **Sakura Pink, Dracula, Color Scheme 15** — removed. Only Catppuccin Mocha survives.
- **Meslo Nerd Fonts** — installed on the machine by Oh My Posh's own installer, not on
  winget, and nothing depends on them now that the JetBrains font name is correct.

`--dangerously-skip-permissions` in `powershell/profile.ps1` is a known, deliberate choice.
It overrides `defaultMode` in `claude/settings.json`. Flag it if asked, don't remove it.
