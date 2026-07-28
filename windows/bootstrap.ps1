<#
.SYNOPSIS
    Phase 0. Puts in place the things everything else depends on: winget, PowerShell 7,
    Developer Mode.

.DESCRIPTION
    Run this FIRST on a fresh Windows 11 Enterprise LTSC install.

    LTSC ships without the Microsoft Store, and winget comes from the Store. So on a clean
    LTSC there is no winget, which means apps\install.ps1 can't run, which means nothing in
    this repo can run. This script breaks that deadlock by fetching App Installer straight
    from GitHub.

    IMPORTANT: this is the only script in the repo written for **Windows PowerShell 5.1**.
    A fresh LTSC has nothing else — PowerShell 7 is one of the things this installs. So no
    &&, no ternaries, no ??, and TLS 1.2 has to be forced by hand.

    Run it elevated. Developer Mode and the machine-wide installs need it.

.PARAMETER SkipDevMode
    Don't enable Developer Mode. Note that dev\install.ps1 needs it to symlink
    KioscoDiagonal into Laragon's www folder.

.EXAMPLE
    # from an elevated Windows PowerShell (not pwsh - it isn't installed yet)
    powershell -ExecutionPolicy Bypass -File windows\bootstrap.ps1
#>
[CmdletBinding()]
param([switch]$SkipDevMode)

$ErrorActionPreference = 'Stop'

function Say  { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Skip { param($m) Write-Host "  [skip] $m" -ForegroundColor DarkGray }
function Warn { param($m) Write-Host "  [!]    $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Step { param($m) Write-Host "`n=== $m" -ForegroundColor Cyan }

# PowerShell 5.1 defaults to SSL3/TLS1.0, which GitHub refuses.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Step "Phase 0 - bootstrap"
Say "PowerShell $($PSVersionTable.PSVersion)"
if (-not $isAdmin) {
    Fail "Not elevated. Re-run this from an admin PowerShell."
    exit 1
}
Ok "running elevated"

$work = Join-Path $env:TEMP 'ws-bootstrap'
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Get-File {
    param([string]$Url, [string]$Out)
    Say "downloading $(Split-Path $Out -Leaf)"
    Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
}

# ================================================================ winget
Step "winget"

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Skip "already present ($(winget --version))"
}
else {
    Warn "not installed - this is expected on LTSC, it ships without the Store"

    # Ask GitHub for the current release rather than pinning a version that will rot.
    $api = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
    $rel = Invoke-RestMethod -Uri $api -UseBasicParsing -Headers @{ 'User-Agent' = 'workstation-bootstrap' }
    Say "winget-cli $($rel.tag_name)"

    $bundleAsset = $rel.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
    $depsAsset = $rel.assets | Where-Object { $_.name -like '*Dependencies.zip' } | Select-Object -First 1

    if (-not $bundleAsset) { Fail "no .msixbundle in the latest release"; exit 1 }

    # Dependencies first, or Add-AppxPackage rejects the bundle.
    if ($depsAsset) {
        $zip = Join-Path $work $depsAsset.name
        Get-File $depsAsset.browser_download_url $zip
        $ext = Join-Path $work 'deps'
        Remove-Item $ext -Recurse -Force -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $ext)

        Get-ChildItem $ext -Recurse -Filter *.appx |
            Where-Object { $_.FullName -match '\\x64\\' } |
            ForEach-Object {
                try { Add-AppxPackage -Path $_.FullName -ErrorAction Stop; Ok "dep $($_.Name)" }
                catch { Skip "dep $($_.Name) - already present or newer" }
            }
    }
    else {
        # Fall back to the documented permalink for the one dependency that always matters.
        $vc = Join-Path $work 'VCLibs.appx'
        Get-File 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' $vc
        try { Add-AppxPackage -Path $vc -ErrorAction Stop; Ok 'dep VCLibs' }
        catch { Skip 'dep VCLibs - already present' }
    }

    $bundle = Join-Path $work $bundleAsset.name
    Get-File $bundleAsset.browser_download_url $bundle
    Add-AppxPackage -Path $bundle
    Ok "App Installer"

    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')

    if (Get-Command winget -ErrorAction SilentlyContinue) { Ok "winget $(winget --version)" }
    else { Warn "installed, but not on PATH yet - open a new terminal and check again" }
}

# ================================================================ PowerShell 7
Step "PowerShell 7"

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    Skip "already present ($(& $pwsh.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'))"
}
elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Say "installing via winget"
    winget install --id Microsoft.PowerShell --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) { Ok 'PowerShell 7' } else { Warn "winget exited $LASTEXITCODE" }
}
else {
    # No winget: pull the MSI straight from the PowerShell repo.
    $api = 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
    $rel = Invoke-RestMethod -Uri $api -UseBasicParsing -Headers @{ 'User-Agent' = 'workstation-bootstrap' }
    $msi = $rel.assets | Where-Object { $_.name -like '*win-x64.msi' } | Select-Object -First 1
    if (-not $msi) { Fail 'no x64 MSI in the latest PowerShell release'; exit 1 }
    $out = Join-Path $work $msi.name
    Get-File $msi.browser_download_url $out
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$out`" /qn ADD_PATH=1"
    Ok "PowerShell 7 ($($rel.tag_name))"
}

# ================================================================ Developer Mode
Step "Developer Mode"

if ($SkipDevMode) {
    Skip 'asked to skip'
    Warn 'dev\install.ps1 needs this to symlink KioscoDiagonal into Laragon'
}
else {
    # Lets a non-elevated process create symlinks. dev\install.ps1 relies on it.
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    $cur = (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    if ($cur -eq 1) {
        Skip 'already on'
    }
    else {
        Set-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
        Ok 'enabled - symlinks no longer need an elevated shell'
    }
}

# ================================================================ done
Step "Next"
Write-Host ''
Say 'Open a NEW terminal so PATH picks up winget and pwsh, then:'
Write-Host ''
Write-Host '    pwsh apps\install.ps1' -ForegroundColor White
Write-Host ''
Say 'Order after that: terminal -> dev -> claude -> windows\install.ps1'
Say 'apps installs Docker and WSL, which need a reboot. It will tell you.'
Write-Host ''
