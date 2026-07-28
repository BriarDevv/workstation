<#
.SYNOPSIS
    Configures git and clones the repos.

.DESCRIPTION
    Reads the repository lists out of the markdown in repos\, the same way
    apps/install.ps1 reads its own tables. Adding a row is enough; nothing here carries a
    second copy of the list.

    git itself comes from apps/. This script only configures it, so it reports and moves on
    when something is missing rather than trying to install it.

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

# Every .md in repos\ except its README is a clone list, so adding a list is adding a file -
# there is nothing to register it in. Splitting them by owner, by client, by whatever, costs
# nothing here.
#
# These tables are shaped differently from the ones in apps/README.md: the useful columns
# are 2 and 3, and column 1 is plain text rather than a backticked ID. That's why
# Get-IdsFromReadme can't read them and this exists instead.
#
# A destination ending in a separator is a parent directory, and the local checkout takes
# its name from column 1 - so a repo can sit on disk under a different name than the one its
# remote carries.
function Get-ReposFromDir {
    param([Parameter(Mandatory)][string]$Dir)

    $repos = [System.Collections.Generic.List[hashtable]]::new()
    if (-not (Test-Path $Dir)) { return $repos }

    $files = Get-ChildItem $Dir -Filter *.md |
        Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name

    foreach ($file in $files) {
        # Reset per file: a table only counts inside a "## The list" section, which is what
        # lets each list explain itself in prose without confusing the parser.
        $inList = $false

        foreach ($line in Get-Content $file.FullName) {
            if ($line -match '^##\s+(.+?)\s*$') { $inList = ($Matches[1].Trim() -eq 'The list'); continue }
            if (-not $inList -or $line -notmatch '^\|') { continue }

            $cells = $line -split '\|'
            if ($cells.Count -lt 4) { continue }

            $name = ($cells[1] -replace '\*\*|`', '').Trim()
            if (-not $name -or $name -match '^-+$' -or $name -eq 'Repo') { continue }

            $remote = ($cells[2] -replace '`', '').Trim()
            $dest = ($cells[3] -replace '`', '').Trim() -replace '^~', $HOME
            if ($dest -match '[\\/]$') { $dest = Join-Path $dest $name }

            $repos.Add(@{ Name = $name; Remote = $remote; Path = $dest; List = $file.BaseName })
        }
    }
    return $repos
}

# ---------------------------------------------------------------- git
Write-Step 'git'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'git\gitconfig') (Join-Path $HOME '.gitconfig'))) {
    $failed.Add('gitconfig')
}

# ---------------------------------------------------------------- repos
Write-Step 'Repos'
$repos = Get-ReposFromDir (Join-Path $PSScriptRoot 'repos')

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
$lists = @(Get-ChildItem (Join-Path $PSScriptRoot 'repos') -Filter *.md -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' })
Write-Host "  $($repos.Count) repos across $($lists.Count) list(s)" -ForegroundColor DarkGray

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
