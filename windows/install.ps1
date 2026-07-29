<#
.SYNOPSIS
    Phase 5. OS tweaks: Explorer, taskbar, Fast Startup, power, telemetry.

.DESCRIPTION
    Runs LAST, because it restarts Explorer.

    Split by privilege on purpose. Everything under HKCU is per-user and needs no
    elevation; the machine-wide settings under HKLM do. Without admin the script does the
    HKCU half and tells you exactly what it skipped, rather than failing or silently
    doing nothing.

    Reports every change as old -> new so you can put anything back by hand.

.PARAMETER SkipExplorerRestart
    Apply the settings but don't restart Explorer. They take effect at next sign-in.

.PARAMETER WhatIfOnly
    Print what would change and exit.

.EXAMPLE
    pwsh windows\install.ps1              # HKCU only if not elevated
    # elevated, for the full set:
    Start-Process pwsh -Verb RunAs -ArgumentList '-File windows\install.ps1'
#>
[CmdletBinding()]
param(
    [switch]$SkipExplorerRestart,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$admin = Test-Admin
$edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
$build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild

Write-Step "Phase 5 - Windows"
Write-Host "  edition $edition  ·  build $build  ·  $(if ($admin) { 'elevated' } else { 'NOT elevated' })"
if ($edition -like '*Eval*') {
    Write-Warn2 "This is an Evaluation SKU - 90 days, then hourly reboots. See usb.md."
}

$changed = 0
$skipped = 0

# Set a registry value, reporting old -> new. Idempotent.
function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [string]$Type = 'DWord',
        [string]$What
    )
    if ($Path -like 'HKLM:*' -and -not $admin) {
        Write-Skip "$What - needs admin"
        $script:skipped++
        return
    }
    if (-not (Test-Path $Path)) {
        if ($WhatIfOnly) { Write-Host "  would create $Path" -ForegroundColor DarkGray; return }
        New-Item -Path $Path -Force | Out-Null
    }
    $old = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($old -eq $Value) { Write-Skip "$What (already $Value)"; return }
    if ($WhatIfOnly) {
        Write-Host "  would set $What : $(if ($null -eq $old) { '(unset)' } else { $old }) -> $Value" -ForegroundColor DarkGray
        return
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    Write-Ok "$What : $(if ($null -eq $old) { '(unset)' } else { $old }) -> $Value"
    $script:changed++
}

# ================================================================ Explorer (per-user)
Write-Step 'Explorer'
$adv = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

Set-Reg $adv 'HideFileExt'          0 -What 'show file extensions'
Set-Reg $adv 'Hidden'               1 -What 'show hidden files'
Set-Reg $adv 'LaunchTo'             1 -What 'open to This PC'
Set-Reg $adv 'ShowTaskViewButton'   0 -What 'hide Task View button'
Set-Reg $adv 'TaskbarDa'            0 -What 'hide Widgets'
Set-Reg $adv 'TaskbarMn'            0 -What 'hide Chat'
Set-Reg $adv 'TaskbarAl'            0 -What 'taskbar aligned left'

Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0 `
    -What 'hide taskbar search box'

# ================================================================ Fast Startup
Write-Step 'Fast Startup'
Write-Host "  Hibernated shutdowns leave NTFS locked, stop driver and BIOS updates from" -ForegroundColor DarkGray
Write-Host "  applying on 'shut down', and confuse WSL2 and Docker. Off on a dev machine." -ForegroundColor DarkGray

Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 `
    -What 'Fast Startup disabled'

# ================================================================ Telemetry
Write-Step 'Telemetry'
# 0 is "Security", and Pro does NOT honour it - it clamps to 1, "Required". Level 0 needs
# Enterprise, Education or an LTSC edition. The value is still written as 0 so the intent
# survives if this machine ever changes edition, but the message says what actually happens,
# because a label claiming Security on a Pro box is a lie you'd only catch by reading Windows'
# own docs.
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 `
    -What 'telemetry to minimum (Pro clamps this to Required; Security needs Enterprise)'

# Load-bearing on Pro in a way it never was on an Enterprise edition: this is the switch that
# stops Windows silently installing "suggested" apps into a brand-new profile - the games and
# trials that reappear after every feature update. See debloat.ps1.
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 `
    -What 'no suggested apps (stops Windows reinstalling bloat later)'

# ================================================================ Power
Write-Step 'Power'
if ($WhatIfOnly) {
    Write-Host '  would set the High performance power scheme' -ForegroundColor DarkGray
}
else {
    $HIGH_PERF = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $active = (powercfg /getactivescheme) -replace '.*GUID: ([a-f0-9-]+).*', '$1'
    if ($active -eq $HIGH_PERF) { Write-Skip 'already on High performance' }
    else {
        powercfg /setactive $HIGH_PERF 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "power scheme -> High performance"; $changed++ }
        else { Write-Warn2 'could not switch scheme - it may not exist on this edition' }
    }
    # A desktop should never sleep the disks out from under Docker.
    powercfg /change standby-timeout-ac 0 2>&1 | Out-Null
    powercfg /change hibernate-timeout-ac 0 2>&1 | Out-Null
    Write-Ok 'sleep and hibernate disabled on AC'
}

# ================================================================ Media Feature Pack
Write-Step 'Media Feature Pack'
if ($edition -notmatch 'N$|NEval$') {
    Write-Skip "not an N edition - nothing to add"
}
elseif (-not $admin) {
    Write-Skip 'N edition detected but needs admin'
    $skipped++
}
elseif ($WhatIfOnly) {
    Write-Host '  would add Media.MediaFeaturePack' -ForegroundColor DarkGray
}
else {
    Write-Warn2 "N edition - no Media Foundation. Video/audio playback, screen sharing in"
    Write-Warn2 "Teams/Zoom/Discord, Electron apps and WSLg all break without this."
    $cap = Get-WindowsCapability -Online -Name 'Media.MediaFeaturePack*' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cap -and $cap.State -eq 'Installed') { Write-Skip 'already installed' }
    elseif ($cap) {
        Add-WindowsCapability -Online -Name $cap.Name
        Write-Ok $cap.Name
        $changed++
    }
    else { Write-Warn2 'capability not offered - needs Windows Update reachable, or the FoD ISO' }
}

# ================================================================ wrap up
Write-Step 'Done'
Write-Host "  $changed changed · $skipped skipped"

if ($skipped -gt 0 -and -not $admin) {
    Write-Host ''
    Write-Warn2 "$skipped machine-wide setting(s) skipped. For those, re-run elevated:"
    Write-Host "    Start-Process pwsh -Verb RunAs -ArgumentList '-File $PSCommandPath'" -ForegroundColor White
}

if ($WhatIfOnly) { return }

if ($SkipExplorerRestart) {
    Write-Warn2 'Explorer not restarted - changes apply at next sign-in'
}
elseif ($changed -gt 0) {
    Write-Host ''
    Write-Host '  restarting Explorer...' -ForegroundColor DarkYellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
    Write-Ok 'Explorer restarted'
}

Write-Host ''
Write-Warn2 'Fast Startup and telemetry changes need a reboot to fully take effect.'
Write-Host ''
