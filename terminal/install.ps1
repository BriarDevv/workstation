<#
.SYNOPSIS
    Applies a terminal style: font, color scheme, transparency, ASCII art, PowerShell profile.

.DESCRIPTION
    Nothing here is edited in place. The look is composed at install time from three inputs:

        styles/<name>.json   the knobs you actually change (font, scheme, opacity, art)
        schemes/*.json       Windows Terminal color schemes, one file each
        windows-terminal/    the base settings.json: profiles, keybindings, everything else

    So trying a new look means adding one file, not editing a 200-line settings.json and
    losing the old one.

    Programs (Windows Terminal, fastfetch, the font) come from apps\install.ps1.

.PARAMETER Style
    Which style to apply. Defaults to "active" in style.json. Applying one also records it
    there, so the repo always says what's on the machine.

.PARAMETER List
    Show available styles, schemes, ASCII art, and the monospaced Nerd Fonts installed on
    this machine. Changes nothing.

.PARAMETER SyncEditorFont
    Also write the style's font into the current user's live VS Code settings, so the
    editor matches. Settings Sync remains the owner of every other editor setting.

.PARAMETER NewStyle
    Scaffold a new style from the active one and stop. Edit the file it prints, then apply
    it with -Style. Nothing on the machine changes.

.PARAMETER SkipUpgrade
    Don't upgrade Windows Terminal / fastfetch. Only when offline or deliberately pinned.

.PARAMETER WhatIfOnly
    Compose and compare every output, but write nothing and install nothing.

.EXAMPLE
    pwsh terminal\install.ps1                          # apply the active style
    pwsh terminal\install.ps1 -List                    # see what's available
    pwsh terminal\install.ps1 -NewStyle tokyo-night    # scaffold a new one
    pwsh terminal\install.ps1 -Style tokyo-night       # switch, and record the switch
    pwsh terminal\install.ps1 -Style tokyo-night -SyncEditorFont
    pwsh terminal\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param(
    [string]$Style,
    [string]$NewStyle,
    [switch]$List,
    [switch]$SyncEditorFont,
    [switch]$SkipUpgrade,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7
$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()

$stylesDir = Join-Path $PSScriptRoot 'styles'
$schemesDir = Join-Path $PSScriptRoot 'schemes'
$artsDir = Join-Path $PSScriptRoot 'ascii-arts'
$statePath = Join-Path $PSScriptRoot 'style.json'

function Read-Json { param($Path) Get-Content $Path -Raw | ConvertFrom-Json }
function Get-StyleNames { (Get-ChildItem $stylesDir -Filter *.json | Sort-Object Name).BaseName }

# ================================================================ -List
if ($List) {
    $active = (Read-Json $statePath).active

    Write-Step 'Styles'
    foreach ($n in Get-StyleNames) {
        $s = Read-Json (Join-Path $stylesDir "$n.json")
        $mark = if ($n -eq $active) { '*' } else { ' ' }
        Write-Host ("  {0} {1,-18} {2}" -f $mark, $n, $s.description) -ForegroundColor $(if ($n -eq $active) { 'Green' } else { 'Gray' })
        Write-Host ("     {0}, {1}pt {2} | {3} | opacity {4}" -f `
                $s.font.family, $s.font.size, $s.font.weight, $s.terminal.colorScheme, $s.terminal.opacity) -ForegroundColor DarkGray
    }
    Write-Host "`n  * = active" -ForegroundColor DarkGray

    Write-Step 'Color schemes'
    Get-ChildItem $schemesDir -Filter *.json | ForEach-Object {
        Write-Host "  $((Read-Json $_.FullName).name)"
    }

    Write-Step 'ASCII art'
    Get-ChildItem $artsDir -Filter *.txt | ForEach-Object { Write-Host "  $($_.Name)" }

    # Nerd Fonts suffix by variant, not by whether the family is monospaced: NFM and the long
    # "Nerd Font Mono" are the forced-mono builds, plain NF keeps the base font's own metrics
    # - which is still monospaced when the base font is, as with Maple Mono NF. Listing only
    # the forced-mono suffixes hid an installed family that a style is legitimately using.
    # NFP / "Nerd Font Propo" stays out: that one really is proportional.
    Write-Step 'Nerd Fonts installed here'
    Write-Host '  (any of these can go in a style''s font.family)' -ForegroundColor DarkGray
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $mono = [System.Drawing.FontFamily]::Families.Name |
        Where-Object { $_ -match '(NFM|NF|Nerd Font( Mono)?)$' } | Sort-Object
    if ($mono) { $mono | ForEach-Object { Write-Host "  $_" } }
    else { Write-Warn2 'none found - install one from apps\install.ps1' }
    exit 0
}

# ================================================================ -NewStyle
if ($NewStyle) {
    if ($NewStyle -notmatch '^[a-z0-9][a-z0-9-]*$') {
        Write-Fail "Use a lowercase kebab-case name, e.g. tokyo-night"
        exit 1
    }
    $dest = Join-Path $stylesDir "$NewStyle.json"
    if (Test-Path $dest) { Write-Fail "styles\$NewStyle.json already exists"; exit 1 }

    if ($script:DryRun) {
        Write-Step "New style: $NewStyle"
        Write-Would "create $dest from the active style"
        exit 0
    }

    $base = Read-Json (Join-Path $stylesDir "$((Read-Json $statePath).active).json")
    $base.'$comment' = "Started from the active style on $(Get-Date -Format 'yyyy-MM-dd'). Edit freely."
    $base.description = "TODO: describe this look"
    $base | ConvertTo-Json -Depth 32 | Set-Content $dest -Encoding utf8

    Write-Step "New style: $NewStyle"
    Write-Ok $dest
    Write-Host ''
    Write-Host '  Next:' -ForegroundColor DarkGray
    Write-Host "    1. Edit styles\$NewStyle.json - font, colorScheme, opacity, asciiArt" -ForegroundColor DarkGray
    Write-Host '    2. If you want a new palette, drop its JSON in schemes\ first' -ForegroundColor DarkGray
    Write-Host "       and point terminal.colorScheme at its 'name'" -ForegroundColor DarkGray
    Write-Host "    3. pwsh terminal\install.ps1 -Style $NewStyle" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Nothing on the machine changed.' -ForegroundColor DarkGray
    exit 0
}

# ================================================================ resolve the style
$state = Read-Json $statePath
if (-not $Style) { $Style = $state.active }

$stylePath = Join-Path $stylesDir "$Style.json"
if (-not (Test-Path $stylePath)) {
    Write-Fail "No style called '$Style'. Available: $((Get-StyleNames) -join ', ')"
    exit 1
}
$st = Read-Json $stylePath

Write-Step "Style: $Style"
Write-Host "  $($st.description)" -ForegroundColor DarkGray

# ================================================================ font must resolve first
Write-Step 'Font'
$wanted = $st.font.family
$real = Resolve-FontFamily "^$([regex]::Escape($wanted))$"

if (-not $real) {
    # Nerd Fonts renames families between releases; find the equivalent instead of failing.
    $stem = ($wanted -replace ' (NFM|NF|NFP|Nerd Font( Mono| Propo)?)$', '')
    $real = Resolve-FontFamily "^$([regex]::Escape($stem)) (NFM|Nerd Font Mono)$"
    if ($real) { Write-Warn2 "'$wanted' isn't registered; using '$real' instead" }
}

if (-not $real) {
    if ($script:DryRun) {
        Write-Warn2 "Font '$wanted' is not installed yet; the apps step would install it first."
        $real = $wanted
    }
    else {
        Write-Fail "Font '$wanted' is not installed, and no Mono variant of it was found."
        Write-Warn2 'Fonts are installed by apps\install.ps1 - from winget, or from the'
        Write-Warn2 '"Fonts outside winget" table in apps\README.md. Run that first.'
        Write-Warn2 "Or run -List to see what's available and put that in styles\$Style.json."
        exit 1
    }
}
Write-Ok "using '$real'"

# ================================================================ stay current
if (-not $SkipUpgrade -and (Test-Cmd winget)) {
    Write-Step 'Keeping the terminal current'
    Write-Host "  Windows Terminal drops settings keys it doesn't recognise, silently." -ForegroundColor DarkGray
    Write-Host '  On an old build this config loads fine and just renders wrong.' -ForegroundColor DarkGray
    foreach ($id in @('Microsoft.WindowsTerminal', 'Fastfetch-cli.Fastfetch')) {
        if ($script:DryRun -and -not (Test-WingetInstalled $id)) {
            Write-Would "keep $id current after apps installs it"
            continue
        }
        if ((Update-WingetPackage $id) -eq 'fail') { $failed.Add("upgrade: $id") }
    }
}

# ================================================================ compose Windows Terminal
Write-Step 'Windows Terminal'

$wt = Read-Json (Join-Path $PSScriptRoot 'windows-terminal\settings.json')

# schemes/ is the source of truth - drop a file in there and it shows up
$wt | Add-Member -NotePropertyName schemes -NotePropertyValue `
    @(Get-ChildItem $schemesDir -Filter *.json | ForEach-Object { Read-Json $_.FullName }) -Force
Write-Ok "$($wt.schemes.Count) color scheme(s) merged in"

if ($wt.schemes.name -notcontains $st.terminal.colorScheme) {
    Write-Fail "Style wants scheme '$($st.terminal.colorScheme)' but there's no file for it in schemes\"
    exit 1
}

$d = $wt.profiles.defaults
foreach ($p in $st.terminal.PSObject.Properties) { $d | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
$d.font | Add-Member -NotePropertyName face -NotePropertyValue $real -Force
$d.font | Add-Member -NotePropertyName size -NotePropertyValue $st.font.size -Force
$d.font | Add-Member -NotePropertyName weight -NotePropertyValue $st.font.weight -Force
$d.font | Add-Member -NotePropertyName cellHeight -NotePropertyValue $st.font.cellHeight -Force

$wtText = ($wt | ConvertTo-Json -Depth 32) + "`n"

# Only write where Windows Terminal already keeps its config - creating the folder for an
# install that isn't there leaves a stray settings.json nothing ever reads.
$wtDirs = @(
    Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -match '^Microsoft\.WindowsTerminal(Preview)?_' |
        ForEach-Object { Join-Path $_.FullName 'LocalState' }
    Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal'
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $wtDirs) {
    if ($script:DryRun) { Write-Would 'write Windows Terminal settings after the apps step installs it' }
    else {
        Write-Warn2 "Windows Terminal isn't installed - run apps\install.ps1 first"
        $failed.Add('Windows Terminal not installed')
    }
}
else {
    foreach ($dir in $wtDirs) {
        $dest = Join-Path $dir 'settings.json'
        if (-not (Install-ConfigText -Destination $dest -Text $wtText -Label $dest)) {
            $failed.Add("Windows Terminal: $dest")
        }
    }
}

# ================================================================ compose fastfetch
Write-Step 'fastfetch'

$cfgDir = Join-Path $HOME '.config\fastfetch'
$ffDest = Join-Path $cfgDir 'config.jsonc'

if (-not $st.fastfetch) {
    # A style may leave fastfetch out entirely - that is how "opens to a bare prompt" is
    # expressed, and it is the reason the fields below are validated only when the block is
    # there. The generated config has to be removed rather than merely left unwritten: the
    # profile keys off its presence, so the previous style's copy would otherwise keep
    # fetching after the switch, and fastfetch with no config at all falls back to its own
    # built-in logo - more decoration, not less.
    if (Test-Path $ffDest) {
        if ($script:DryRun) { Write-Would "back up and remove $ffDest" }
        else {
            Backup-ExistingFile $ffDest | Out-Null
            Remove-Item -LiteralPath $ffDest -Force
            Write-Ok "removed $ffDest"
        }
    }
    Write-Ok 'style declares no fetch - startup stays bare'
}
else {
    $artsDst = Join-Path $cfgDir 'ascii-arts'
    if (-not $script:DryRun) { New-Item -ItemType Directory -Force -Path $artsDst | Out-Null }

    $arts = Get-ChildItem $artsDir -Filter *.txt
    foreach ($a in $arts) {
        if (-not (Install-ConfigFile $a.FullName (Join-Path $artsDst $a.Name))) {
            $failed.Add("ASCII art: $($a.Name)")
        }
    }
    Write-Ok "$($arts.Count) ASCII art file(s)"

    if (-not (Test-Path (Join-Path $artsDir $st.fastfetch.asciiArt))) {
        Write-Fail "Style wants '$($st.fastfetch.asciiArt)' but it isn't in ascii-arts\"
        exit 1
    }

    # The whole fetch comes from the style: logo, colors, and which modules show on startup.
    # There's no base config file - one style file is the single place to edit.
    if (-not $st.fastfetch.modules) {
        Write-Fail "Style '$Style' has no fastfetch.modules - it wouldn't render anything."
        exit 1
    }

    $ff = [ordered]@{
        '$schema' = 'https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json'
        logo      = [ordered]@{
            type = 'file'
            # Absolute path, rewritten for whoever's $HOME this is - so the repo survives a rename.
            source = "$($HOME.Replace('\','/'))/.config/fastfetch/ascii-arts/$($st.fastfetch.asciiArt)"
        }
    }
    if ($st.fastfetch.logoColors) { $ff.logo.color = $st.fastfetch.logoColors }
    if ($st.fastfetch.logoPadding) { $ff.logo.padding = $st.fastfetch.logoPadding }
    if ($st.fastfetch.display) { $ff.display = $st.fastfetch.display }
    $ff.modules = $st.fastfetch.modules

    # ConvertTo-Json escapes the Nerd Font glyphs to \uXXXX. That's valid JSON and fastfetch
    # reads it fine, but the file becomes unreadable, so unescape before writing.
    $json = [regex]::Replace(
        ($ff | ConvertTo-Json -Depth 32),
        '\\u([0-9a-fA-F]{4})',
        { param($m) [char][int]('0x' + $m.Groups[1].Value) })

    if (-not (Install-ConfigText -Destination $ffDest -Text ($json + "`n") -Label $ffDest)) {
        $failed.Add('fastfetch config')
    }

    $shown = @($st.fastfetch.modules | Where-Object { $_ -isnot [string] -and $_.type } | ForEach-Object { $_.type })
    Write-Ok "logo -> $($st.fastfetch.asciiArt)"
    Write-Ok "modules -> $($shown -join ', ')"
}

# ================================================================ PowerShell profile
Write-Step 'PowerShell profile'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'powershell\profile.ps1') $PROFILE.CurrentUserCurrentHost)) {
    $failed.Add('PowerShell profile')
}

# ================================================================ editor font
if ($SyncEditorFont) {
    Write-Step 'VS Code font'
    # The live file only. The repo holds no VS Code config - Settings Sync owns it, see
    # dev/README.md - so there is no second copy here to keep in step.
    $f = Join-Path $env:APPDATA 'Code\User\settings.json'
    $editorValue = "$real, Consolas, monospace"
    $terminalValue = $real

    if (Test-Path $f) {
        $t = Get-Content $f -Raw
        foreach ($entry in @(
            @{ Key = 'editor.fontFamily'; Value = $editorValue }
            @{ Key = 'terminal.integrated.fontFamily'; Value = $terminalValue }
        )) {
            $pattern = '("' + [regex]::Escape($entry.Key) + '"\s*:\s*")[^"]*(")'
            if ($t -match $pattern) {
                $escaped = $entry.Value.Replace('$', '$$')
                $t = [regex]::Replace($t, $pattern, "`${1}$escaped`${2}")
                continue
            }

            $closing = $t.LastIndexOf('}')
            if ($closing -lt 0) {
                Write-Fail "$f has no closing object brace"
                $failed.Add('VS Code font')
                break
            }
            $before = $t.Substring(0, $closing).TrimEnd()
            $comma = if ($before.EndsWith('{') -or $before.EndsWith(',')) { '' } else { ',' }
            $jsonValue = $entry.Value | ConvertTo-Json -Compress
            $t = $before + $comma + "`r`n  `"$($entry.Key)`": $jsonValue`r`n" + $t.Substring($closing)
        }
    }
    else {
        $t = (@{
            'editor.fontFamily' = $editorValue
            'terminal.integrated.fontFamily' = $terminalValue
        } | ConvertTo-Json) + "`n"
    }

    if (-not ($failed -contains 'VS Code font') -and
        -not (Install-ConfigText -Destination $f -Text $t -Label $f)) {
        $failed.Add('VS Code font')
    }
}

# ================================================================ record it
if ($state.active -ne $Style) {
    $state.active = $Style
    $stateText = ($state | ConvertTo-Json -Depth 8) + "`n"
    if (Install-ConfigText -Destination $statePath -Text $stateText -Label 'style.json active style') {
        Write-Ok "style.json now says active = $Style"
    }
    else { $failed.Add('style.json') }
}

Write-Host ''
if ($failed.Count) {
    Write-Fail "$($failed.Count) terminal step(s) failed:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    exit 1
}
if ($script:DryRun) { Write-Ok "Dry run complete for '$Style'; nothing changed." }
else { Write-Ok "Done. Open a new tab to see '$Style'." }
Write-Host ''
exit 0
