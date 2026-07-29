<#
.SYNOPSIS
    Removes the AppX and Win32 apps listed in README.md.

.DESCRIPTION
    Reads AppX names from README.md's "Inbox apps" table and winget IDs from "Win32 apps".
    The tables are the complete removal manifest - this script holds no removable names of
    its own.

    This is the one script in the repo that DELETES rather than configures, so it is the one
    that most deserves a dry run first. Package names can change between Windows releases;
    -List is how you compare the manifest with the current machine.

    AppX removal is intentionally limited to the current user and is reversible through the
    Store. This personal workstation has one account, so provisioned packages and unrelated
    profiles are outside the desired state. Win32 targets are uninstalled through winget.

    Idempotent: an app that isn't there is a skip, not a failure.

.PARAMETER List
    Show every removable app on this machine and exit. Removes nothing. Use it to check the
    table against reality before believing either.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh windows\debloat.ps1 -List
    pwsh windows\debloat.ps1 -WhatIfOnly
    pwsh windows\debloat.ps1
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$readme = Join-Path $PSScriptRoot 'README.md'

# Never removable, whatever any table says. Appx is unforgiving - take out a framework or the
# Store and the fix is a repair install, not an undo. This guard exists because the list of
# names lives in a markdown file that is easy to edit and impossible to type-check.
$PROTECTED = @(
    'Microsoft.WindowsStore'              # one-way door on Pro
    'Microsoft.DesktopAppInstaller'       # winget itself
    'Microsoft.StorePurchaseApp'          # Store licensing and purchases
    'Microsoft.VCLibs'                    # C++ runtime, half the Store depends on it
    'Microsoft.UI.Xaml'                   # UI framework, same
    'Microsoft.NET'                       # .NET native framework
    'MicrosoftCorporationII.WinAppRuntime' # current Windows App Runtime packages
    'Microsoft.Winget.Source'             # winget package source metadata
    'Microsoft.PowerShell'                # Store-distributed PowerShell, when present
    'Microsoft.ApplicationCompatibilityEnhancements' # compatibility fixes from Store
    'MicrosoftCorporationII.WindowsSubsystemForLinux' # WSL application package
    'Microsoft.WindowsTerminal'           # apps\ installs it on purpose
    'Microsoft.WindowsCalculator'         # chosen local fallback
    'Microsoft.WindowsNotepad'            # chosen local fallback
    'Microsoft.ScreenSketch'              # Snipping Tool
    'Microsoft.Windows.Photos'            # default image handler, no replacement installed
    'Microsoft.ZuneMusic'                 # Media Player
    'Microsoft.AV1VideoExtension'         # media codecs used by browsers and local players
    'Microsoft.AVCEncoderVideoExtension'
    'Microsoft.HEIFImageExtension'
    'Microsoft.HEVCVideoExtension'
    'Microsoft.MPEG2VideoExtension'
    'Microsoft.RawImageExtension'
    'Microsoft.VP9VideoExtensions'
    'Microsoft.WebMediaExtensions'
    'Microsoft.WebpImageExtension'
    'Microsoft.GamingApp'                 # Xbox / Game Pass
    'Microsoft.GamingServices'            # Store and Game Pass runtime
    'Microsoft.Xbox'                      # every Xbox integration package
    'Microsoft.Edge.GameAssist'           # Xbox Game Bar browser overlay
    'Microsoft.MicrosoftEdge'             # Edge stays installed but dormant
    'MicrosoftWindows.Client.CBS'          # shell servicing components
    'MicrosoftWindows.Client.Core'
    'MicrosoftWindows.Client.CoreAI'
    'MicrosoftWindows.Client.FileExp'
    'MicrosoftWindows.Client.OOBE'
    'MicrosoftWindows.Client.Photon'
    'Microsoft.SecHealthUI'               # Windows Security UI
    'AdvancedMicroDevicesInc-2.AMDRadeonSoftware' # display-driver control panel
    'NVIDIACorp.NVIDIAControlPanel'
    'RealtekSemiconductorCorp.RealtekAudioControl'
)

function Test-Protected {
    param([Parameter(Mandatory)][string]$Name)
    foreach ($p in $PROTECTED) { if ($Name -like "$p*") { return $true } }
    return $false
}

# ---------------------------------------------------------------- -List
if ($List) {
    Write-Step 'Removable apps on this machine'
    Write-Host '  Frameworks and system components are hidden - they are never candidates.' -ForegroundColor DarkGray
    Write-Host ''

    $wanted = @(Get-IdsFromReadme $readme @('Inbox apps'))
    $win32Wanted = @(Get-IdsFromReadme $readme @('Win32 apps'))
    $apps = @(Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.NonRemovable -ne $true } | Sort-Object Name)
    $candidates = @($apps | Where-Object { -not (Test-Protected $_.Name) })

    foreach ($a in $candidates) {
        $mark = if ($wanted -contains $a.Name) { '[in table]' } else { '          ' }
        $colour = if ($wanted -contains $a.Name) { 'Yellow' } else { 'Gray' }
        Write-Host ("  $mark {0}" -f $a.Name) -ForegroundColor $colour
    }

    Write-Host ''
    Write-Host "  $($candidates.Count) removable, $(@($candidates | Where-Object { $wanted -contains $_.Name }).Count) of them named in the table." -ForegroundColor DarkGray
    Write-Host '  Anything above without [in table] that you do not want needs a row in README.md.' -ForegroundColor DarkGray

    if ($win32Wanted.Count) {
        Write-Host ''
        Write-Host '  Win32 removals:' -ForegroundColor DarkGray
        foreach ($id in $win32Wanted) {
            $state = if ((Test-Cmd winget) -and (Test-WingetInstalled $id)) { '[installed]' } else { '[absent]' }
            Write-Host "    $state $id" -ForegroundColor $(if ($state -eq '[installed]') { 'Yellow' } else { 'DarkGray' })
        }
    }
    Write-Host ''
    exit 0
}

# ---------------------------------------------------------------- remove
Write-Step 'Inbox apps'
$wanted = @(Get-IdsFromReadme $readme @('Inbox apps'))
$win32Wanted = @(Get-IdsFromReadme $readme @('Win32 apps'))
if (-not $wanted.Count -and -not $win32Wanted.Count) {
    Write-Fail 'no packages found under "## Inbox apps" or "## Win32 apps" in README.md'
    exit 1
}

Write-Host "  $($wanted.Count) in the table, current user only" -ForegroundColor DarkGray

$removed = 0
$absent = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($name in $wanted) {
    if (Test-Protected $name) {
        Write-Warn2 "$name is protected and will not be removed - take the row out of README.md"
        continue
    }

    $pkg = @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    if (-not $pkg.Count) {
        # Not a failure. It may already have been removed, or this Windows build may not ship
        # it. In both cases the declared end state is satisfied; keep the row so a later
        # feature update or fresh install cannot silently bring it back.
        $absent.Add($name)
        continue
    }

    if ($script:DryRun) { Write-Would "remove $name"; $removed++; continue }

    try {
        $pkg | Remove-AppxPackage -ErrorAction Stop
        Write-Ok $name
        $removed++
    }
    catch {
        Write-Warn2 "$name - $($_.Exception.Message)"
        $failed.Add($name)
    }
}

# ---------------------------------------------------------------- Win32 remove
if ($win32Wanted.Count) {
    Write-Step 'Win32 apps'
    if (-not (Test-Cmd winget)) {
        Write-Warn2 'winget is unavailable - Win32 removals cannot run'
        foreach ($id in $win32Wanted) { $failed.Add($id) }
    }
    else {
        foreach ($id in $win32Wanted) {
            if (-not (Test-WingetInstalled $id)) {
                $absent.Add($id)
                continue
            }
            if ($script:DryRun) { Write-Would "uninstall $id through winget"; $removed++; continue }

            & winget uninstall --id $id --exact --silent --disable-interactivity --accept-source-agreements 2>&1 |
                Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
            if ($LASTEXITCODE -eq 0) { Write-Ok $id; $removed++ }
            else { Write-Warn2 "$id - winget exit $LASTEXITCODE"; $failed.Add($id) }
        }
    }
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
$verb = if ($script:DryRun) { 'planned for removal' } else { 'removed' }
Write-Host "  $removed $verb, $($absent.Count) not present, $($failed.Count) failed" -ForegroundColor DarkGray

if ($absent.Count) {
    Write-Host ''
    Write-Skip "$($absent.Count) already absent on this machine:"
    foreach ($a in $absent) { Write-Host "         $a" -ForegroundColor DarkGray }
    Write-Host '         Kept in the desired-state list so a fresh install or feature update' -ForegroundColor DarkGray
    Write-Host '         cannot reintroduce them unnoticed.' -ForegroundColor DarkGray
}

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''
Write-Host '  install.ps1 disables the Pro-supported consumer surfaces. Re-run this script' -ForegroundColor DarkGray
Write-Host '  after a feature update if the package inventory changes.' -ForegroundColor DarkGray
Write-Host ''
exit 0
