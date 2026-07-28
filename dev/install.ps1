<#
.SYNOPSIS
    Configures the development environment: VS Code, git, and the repos to clone.

.DESCRIPTION
    Reads its lists out of the markdown next to it, the same way apps/install.ps1 does -
    extension IDs from vscode/extensions.md, repositories from repos.md. Adding a row is
    enough; nothing here carries a second copy of either list.

    The programs themselves come from apps/. This script only configures them, so it
    reports and moves on when one is missing rather than trying to install it.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it isn't, and
    the summary names what.

.PARAMETER SkipRepos
    Don't clone anything. Useful on a machine where the code is already checked out.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh dev\install.ps1
    pwsh dev\install.ps1 -WhatIfOnly
    pwsh dev\install.ps1 -SkipRepos
#>
[CmdletBinding()]
param(
    [switch]$SkipRepos,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly

$failed = [System.Collections.Generic.List[string]]::new()

# The binary moves; the config directory doesn't. On this machine VS Code sits in
# C:\Briar\Code\VSC, and winget restores it to %LOCALAPPDATA%\Programs - so the path is
# resolved, never assumed. The PATH fallback matters in a fresh restore: apps\install.ps1
# may have installed VS Code minutes ago in a shell whose PATH predates it, and a `code`
# that isn't on PATH yet is not the same thing as a VS Code that isn't installed.
function Resolve-Code {
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
            "${env:ProgramFiles}\Microsoft VS Code\bin\code.cmd"
        )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# repos.md's table is shaped differently from the ones in apps/README.md: the useful
# columns are 2 and 3, and column 1 is plain text rather than a backticked ID. That's why
# Get-IdsFromReadme can't read it and this exists instead.
#
# A destination ending in a separator is a parent directory, and the local checkout takes
# its name from column 1 - which is how a repo can sit on disk under a shorter name than
# the one its remote carries.
function Get-ReposFromMd {
    param([Parameter(Mandatory)][string]$Path)

    $inList = $false
    $repos = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($line in Get-Content $Path) {
        if ($line -match '^##\s+(.+?)\s*$') { $inList = ($Matches[1].Trim() -eq 'The list'); continue }
        if (-not $inList -or $line -notmatch '^\|') { continue }

        $cells = $line -split '\|'
        if ($cells.Count -lt 4) { continue }

        $name = ($cells[1] -replace '\*\*|`', '').Trim()
        if (-not $name -or $name -match '^-+$' -or $name -eq 'Repo') { continue }

        $remote = ($cells[2] -replace '`', '').Trim()
        $dest = ($cells[3] -replace '`', '').Trim() -replace '^~', $HOME
        if ($dest -match '[\\/]$') { $dest = Join-Path $dest $name }

        $repos.Add(@{ Name = $name; Remote = $remote; Path = $dest })
    }
    return $repos
}

# ---------------------------------------------------------------- VS Code
Write-Step 'VS Code'
$code = Resolve-Code

# %APPDATA%\Code\User is where VS Code reads user config from, whichever copy is running.
$userDir = Join-Path $env:APPDATA 'Code\User'
foreach ($f in 'settings.json', 'keybindings.json') {
    if (-not (Install-ConfigFile (Join-Path $PSScriptRoot "vscode\$f") (Join-Path $userDir $f))) {
        $failed.Add("vscode/$f")
    }
}

$wanted = Get-IdsFromReadme (Join-Path $PSScriptRoot 'vscode\extensions.md') @(
    'Frontend', 'TypeScript', 'PHP', 'Python', 'Git',
    'Docker and remote', 'APIs', 'Themes and icons', 'Utilities'
)

if (-not $code) {
    Write-Warn2 "$($wanted.Count) extensions skipped - VS Code isn't installed. Run apps\install.ps1 first."
    $failed.Add('VS Code (not installed)')
}
else {
    Write-Host "  $($wanted.Count) extensions, from vscode\extensions.md" -ForegroundColor DarkGray

    # There's no upgrade pass here, and no -SkipUpgrade to suppress one. VS Code updates
    # extensions itself - extensions.autoUpdate defaults to true and settings.json doesn't
    # override it - so the house "latest stable, always" rule is already satisfied without
    # this script reinstalling thirty-one things on every run to find that out.
    Write-Host '  VS Code updates these itself; this only installs what is missing.' -ForegroundColor DarkGray

    # One call, not one per extension. `code --list-extensions` costs about a second of
    # process startup, and asking it once per row to learn what a single answer already
    # contains would be most of the runtime of this script.
    $have = @(& $code --list-extensions 2>$null)

    foreach ($id in $wanted) {
        if ($have -contains $id) { Write-Skip $id; continue }
        if ($script:DryRun) { Write-Would "install extension $id"; continue }

        Write-Host "  ...installing $id" -ForegroundColor DarkYellow
        & $code --install-extension $id --force 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok $id }
        else {
            Write-Warn2 "$id exited with code $LASTEXITCODE"
            $failed.Add("extension: $id")
        }
    }
}

# ---------------------------------------------------------------- git
Write-Step 'git'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'git\gitconfig') (Join-Path $HOME '.gitconfig'))) {
    $failed.Add('gitconfig')
}

# ---------------------------------------------------------------- repos
Write-Step 'Repos'
$repos = Get-ReposFromMd (Join-Path $PSScriptRoot 'repos.md')

if ($SkipRepos) {
    Write-Skip "$($repos.Count) repos skipped - -SkipRepos"
}
elseif (-not (Test-Cmd gh)) {
    Write-Warn2 "$($repos.Count) repos skipped - gh isn't installed. Run apps\install.ps1 first."
    $failed.Add('gh (not installed)')
}
else {
    # Checked once, up front. Every clone here is over HTTPS against a private account, so
    # without a login they would all fail the same way - and failing seven times for one
    # reason reads like seven problems.
    gh auth status 2>&1 | Out-Null
    $authed = $LASTEXITCODE -eq 0

    if (-not $authed -and -not $script:DryRun) {
        Write-Warn2 "$($repos.Count) repos skipped - not logged in. Run:  gh auth login"
        Write-Host '         Account BriarDevv, HTTPS. An OAuth flow cannot be scripted.' -ForegroundColor DarkGray
        $failed.Add('gh auth login')
    }
    else {
        foreach ($r in $repos) {
            if (Test-Path (Join-Path $r.Path '.git')) { Write-Skip "$($r.Name) already cloned"; continue }
            if (Test-Path $r.Path) {
                Write-Warn2 "$($r.Name) - $($r.Path) exists and is not a git repo, left alone"
                $failed.Add("repo: $($r.Name)")
                continue
            }
            if ($script:DryRun) { Write-Would "clone $($r.Remote) -> $($r.Path)"; continue }

            Write-Host "  ...cloning $($r.Remote)" -ForegroundColor DarkYellow
            git clone --quiet "https://github.com/$($r.Remote).git" $r.Path 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$($r.Name) -> $($r.Path)" }
            else {
                Write-Warn2 "$($r.Name) clone exited with code $LASTEXITCODE"
                $failed.Add("repo: $($r.Name)")
            }
        }
    }
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
Write-Host "  $($wanted.Count) extensions, $($repos.Count) repos" -ForegroundColor DarkGray

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host '  Re-running is safe and skips everything that already worked.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''
