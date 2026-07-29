<#
.SYNOPSIS
    Runs every folder's install.ps1, in order.

.DESCRIPTION
    This is the whole restore. Each folder still runs standalone - this only decides the
    order, forwards the flags each one understands, and stops where continuing would be a
    lie.

    It stops for exactly one thing: a pending reboot after apps/. Docker and WSL don't work
    until the machine restarts, and every step after that configures programs.

    Failures don't abort the run. One folder failing shouldn't cost you the other five, so
    they're collected and printed together at the end - the same contract each folder
    already gives its own steps. Exit code 0 means every folder finished clean.

.PARAMETER Only
    Run just these folders. They always keep the canonical restore order regardless of the
    order supplied. Positional:  pwsh .\install.ps1 claude

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.PARAMETER Optional
    Forwarded to apps\ - also install its "Optional" table.

.PARAMETER SkipUpgrade
    Forwarded to apps\ and terminal\ - don't upgrade what's already installed.

.PARAMETER Secrets
    Forwarded to claude\ - also sync declared user-scope MCP servers from secrets\.env.

.EXAMPLE
    pwsh .\install.ps1
    pwsh .\install.ps1 -WhatIfOnly
    pwsh .\install.ps1 claude
    pwsh .\install.ps1 layout apps
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)][string[]]$Only,
    [switch]$WhatIfOnly,
    [switch]$Optional,
    [switch]$SkipUpgrade,
    [switch]$Secrets
)

. "$PSScriptRoot\_lib.ps1"
Assert-PowerShell7

# The order. README.md and CLAUDE.md also show it, for a human reading the repo - this table
# is the one that executes, and both of them say so.
#
# Every normal restore step accepts -WhatIfOnly. Destructive debloat remains a separate,
# explicitly-invoked script.
$STEPS = @(
    @{ Name = 'layout'; What = 'the folder tree' }
    @{ Name = 'apps'; What = 'the binaries' }
    @{ Name = 'terminal'; What = 'the look' }
    @{ Name = 'dev'; What = 'git, repos' }
    @{ Name = 'claude'; What = 'Claude Code' }
    @{ Name = 'windows'; What = 'Explorer tweaks - restarts Explorer' }
)

# Windows' own signals, not a guess based on what we just installed. Anything can leave a
# reboot pending - a driver, an update that landed mid-run - and the consequence is the same
# either way, so ask the machine rather than infer it.
function Test-RebootPending {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($k in $keys) { if (Test-Path $k) { return $true } }
    $sm = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
    return [bool]$sm.PendingFileRenameOperations
}

# ---------------------------------------------------------------- what to run
$plan = if ($Only) {
    $bad = @($Only | Where-Object { $_ -notin $STEPS.Name })
    if ($bad) {
        Write-Fail "unknown folder(s): $($bad -join ', ')"
        Write-Host "  Valid: $($STEPS.Name -join ', ')" -ForegroundColor DarkGray
        exit 1
    }
    # Filter the source-of-truth table rather than projecting the user's argument order.
    # `install.ps1 dev layout` still has to run layout before dev.
    @($STEPS | Where-Object { $_.Name -in $Only })
}
else { $STEPS }

# Re-wrap. The if/else above returns its value through the pipeline, which unwraps a
# one-element array back into the bare hashtable - and then $plan.Count is the number of
# KEYS in that hashtable, not the number of steps. `install.ps1 claude` reported "3 folders".
$plan = @($plan)

# ---------------------------------------------------------------- winget first
# Nothing here runs without it. Checked once, up front, because failing six times for one
# reason reads like six problems.
if (-not (Test-Cmd winget) -and ($plan.Name -contains 'apps')) {
    Write-Fail 'winget is missing, and apps\ cannot run without it.'
    Write-Host '  Windows 11 Pro does ship it, inside App Installer - so this usually means App' -ForegroundColor DarkGray
    Write-Host '  Installer has not registered for your user yet. Check the Store, then:' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '      powershell -ExecutionPolicy Bypass -File windows\bootstrap.ps1' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Elevated, and with Windows PowerShell 5.1 - not pwsh, which it also installs.' -ForegroundColor DarkGray
    exit 1
}

Write-Host ''
Write-Host "  Running $($plan.Count) folder(s): $($plan.Name -join ' -> ')" -ForegroundColor Cyan
if ($WhatIfOnly) { Write-Host '  Dry run - nothing will be changed.' -ForegroundColor DarkCyan }
Write-Host ''

# ---------------------------------------------------------------- run
$failed = [System.Collections.Generic.List[string]]::new()
$ran = [System.Collections.Generic.List[string]]::new()
$stoppedAt = $null

foreach ($step in $plan) {
    $script = Join-Path $PSScriptRoot "$($step.Name)\install.ps1"
    if (-not (Test-Path $script)) {
        Write-Warn2 "$($step.Name)\install.ps1 doesn't exist - skipped"
        $failed.Add("$($step.Name) (no install.ps1)")
        continue
    }

    # Only what each script actually declares. Passing a switch a script doesn't have is a
    # hard parameter-binding error, which is why this is a per-step decision rather than one
    # splat for everyone.
    $argv = @{}
    if ($WhatIfOnly) { $argv.WhatIfOnly = $true }
    switch ($step.Name) {
        'apps' { if ($Optional) { $argv.Optional = $true }; if ($SkipUpgrade) { $argv.SkipUpgrade = $true } }
        'terminal' { if ($SkipUpgrade) { $argv.SkipUpgrade = $true } }
        'claude' { if ($Secrets) { $argv.Secrets = $true } }
    }

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host "  $($step.Name.ToUpper()) - $($step.What)" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray

    # Reset first so a folder cannot inherit a native exit code from the preceding folder.
    # Every folder now ends with an explicit exit code, so zeroing the input cannot hide a
    # real failure.
    $global:LASTEXITCODE = 0
    try {
        & $script @argv
        if ($LASTEXITCODE -ne 0) { $failed.Add($step.Name) }
    }
    catch {
        # A child normally reports its own failures and exits non-zero. This catches the
        # unexpected terminating errors so one broken folder cannot hide the result of all
        # the independent folders after it.
        Write-Fail "$($step.Name) stopped unexpectedly: $($_.Exception.Message)"
        $failed.Add("$($step.Name) (unexpected error)")
        $global:LASTEXITCODE = 1
    }
    $ran.Add($step.Name)

    # The one hard stop. Everything after apps\ configures programs, and a program that
    # needs a reboot to exist can't be configured yet - so continuing would produce a run
    # that looks finished and isn't.
    if ($step.Name -eq 'apps' -and -not $WhatIfOnly -and (Test-RebootPending)) {
        $stoppedAt = $step.Name
        break
    }
}

# ---------------------------------------------------------------- summary
Write-Host ''
Write-Host ('=' * 72) -ForegroundColor DarkGray
Write-Step 'Summary'
Write-Host "  ran: $($ran -join ', ')" -ForegroundColor DarkGray

if ($stoppedAt) {
    $left = @($plan.Name | Where-Object { $_ -notin $ran })
    $resumeArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $left) { $resumeArgs.Add($name) }
    if ($SkipUpgrade) { $resumeArgs.Add('-SkipUpgrade') }
    if ($Secrets) { $resumeArgs.Add('-Secrets') }
    Write-Host ''
    Write-Warn2 'REBOOT REQUIRED - stopped here on purpose.'
    Write-Host '         Docker and WSL do not work until the machine restarts, and everything' -ForegroundColor DarkGray
    Write-Host '         left configures programs. Restart, then finish with:' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "             pwsh .\install.ps1 $($resumeArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ''
}

if ($failed.Count) {
    Write-Fail "$($failed.Count) folder(s) reported a problem: $($failed -join ', ')"
    Write-Host '  Scroll up - each one names what, and re-running is safe.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

if (-not $stoppedAt) {
    Write-Ok 'every folder finished clean'
    Write-Host ''
    Write-Host '  Still needs a human: the logins, the API keys, and the "Manual afterwards"' -ForegroundColor DarkGray
    Write-Host '  list apps\ printed above. Those are wanted programs that nothing here installs.' -ForegroundColor DarkGray
    Write-Host ''
}
exit 0
