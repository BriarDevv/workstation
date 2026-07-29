<#
.SYNOPSIS
    Creates the folder tree and locks down its root.

.DESCRIPTION
    The tree is declared in LAYOUT.md and nowhere else - this script only reads it, so
    moving a folder is a one-line edit there rather than a hunt through scripts.

    Runs FIRST in the install order: apps/install.ps1 unpacks Node inside the tree and
    dev/install.ps1 clones into it, so the tree has to exist before either.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it isn't, and
    the summary names what.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh layout\install.ps1
    pwsh layout\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param([switch]$WhatIfOnly)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------- the tree
Write-Step 'Tree'

$wanted = [System.Collections.Generic.List[string]]::new()
foreach ($row in Get-LayoutRows | Where-Object { $_.Created }) { $wanted.Add($row.Path) }

# One folder per list in dev\repos\, derived rather than declared. Adding a list is adding a
# file - the same contract dev/install.ps1 already gives the clones - so a new category
# can't exist in one of the two places and not the other.
$reposRoot = Get-LayoutPath 'repos'
$listDir = Join-Path $PSScriptRoot '..\dev\repos'
foreach ($f in @(Get-ChildItem $listDir -Filter *.md -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name)) {
    $wanted.Add((Join-Path $reposRoot $f.BaseName))
}

foreach ($path in $wanted) {
    if (Test-Path $path) { Write-Skip $path; continue }
    if ($script:DryRun) { Write-Would "create $path"; continue }
    try {
        # -Force here creates missing parents. It is safe because the target is a directory;
        # the truncation hazard in CLAUDE.md is about -Force on a FILE.
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Ok $path
    }
    catch {
        Write-Fail "$path - $($_.Exception.Message)"
        $failed.Add($path)
    }
}

# ---------------------------------------------------------------- the map
# A copy of LAYOUT.md at the root of the tree, for whoever opens that folder without this
# repo in front of them - which on this machine is a real scenario, since the tree outlives
# any particular checkout of the repo that built it.
#
# The repo's copy stays the source: Get-LayoutRows reads that one, never this one. This is
# documentation left where it will be found, not a second input.
Write-Step 'Map'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'LAYOUT.md') (Join-Path (Get-LayoutPath 'root') 'LAYOUT.md'))) {
    $failed.Add('LAYOUT.md at the root')
}

# ---------------------------------------------------------------- permissions
# A custom root can inherit an ACL that hands Authenticated Users write access to everything
# below it. The target is an application-directory ACL: SYSTEM, Administrators, and owner.
#
# icacls rather than Set-Acl, and this is not a style preference. Set-Acl CANNOT remove an
# inherited ACE: RemoveAccessRule can return $true while the entry remains. A permissions
# change that fails silently is worse than one that doesn't run.
#
# The three grants are not optional either. /inheritance:r drops every inherited entry, and
# C: only gives BUILTIN\Users ReadAndExecute - so without re-granting, an unelevated session
# (which is every session) would find the tree read-only and the clones in dev/ would fail.
# SIDs rather than names because the well-known ones are localised and these are not.
Write-Step 'Permissions'
$root = Get-LayoutPath 'root'

if (-not (Test-Path $root)) {
    # On a clean-machine dry run the Tree phase only previews creation, so there is no ACL
    # to inspect yet. The real run creates the root before reaching this point.
    if ($script:DryRun) {
        Write-Would "harden $root after creating it"
    }
    else {
        Write-Fail "$root does not exist, so its permissions cannot be hardened"
        $failed.Add('root ACL')
    }
}
else {
    $acl = Get-Acl $root
    $loose = @($acl.Access | Where-Object { $_.IdentityReference.Value -eq 'NT AUTHORITY\Authenticated Users' })

    if (-not $acl.AreAccessRulesProtected -or $loose.Count) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($script:DryRun) {
        Write-Would "stop $root inheriting from C:\, drop Authenticated Users, grant SYSTEM, Administrators and $me full control"
    }
    else {
        # Splatted, not written inline. A native command takes its arguments as an array, and
        # writing them out with backticks and commas turns the commas into array literals -
        # icacls then sees one argument where it expected four and reports success anyway.
        $icaclsArgs = @(
            '/inheritance:r'
            '/grant', '*S-1-5-18:(OI)(CI)F'        # SYSTEM
            '/grant', '*S-1-5-32-544:(OI)(CI)F'    # BUILTIN\Administrators
            '/grant', "${me}:(OI)(CI)F"            # the interactive user
            '/q'
        )
        & icacls $root @icaclsArgs | Out-Null

        # icacls exit code alone isn't enough - re-read and check the thing we actually want.
        $after = Get-Acl $root
        $still = @($after.Access | Where-Object { $_.IdentityReference.Value -eq 'NT AUTHORITY\Authenticated Users' })
        $mine = @($after.Access | Where-Object { $_.IdentityReference.Value -eq $me -and $_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write })

        if ($LASTEXITCODE -eq 0 -and -not $still.Count -and $mine.Count) {
            Write-Ok "$root - Authenticated Users removed, $me keeps full control"
        }
        else {
            Write-Fail "$root - icacls exited $LASTEXITCODE, Authenticated Users present: $([bool]$still.Count), you can still write: $([bool]$mine.Count)"
            $failed.Add('root ACL')
        }
    }
    }
    else {
        Write-Skip "$root already hardened"
    }
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
Write-Host "  $($wanted.Count) folders declared" -ForegroundColor DarkGray

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
exit 0
