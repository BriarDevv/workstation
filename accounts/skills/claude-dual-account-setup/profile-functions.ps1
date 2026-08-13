# Canonical source for the two Claude Code account commands.
#
# This file is NOT dot-sourced by $PROFILE. repair.ps1 copies its contents into
# a marked block inside $PROFILE, so the profile stays self-contained and keeps
# working even if this skill directory is moved or deleted.
# terminal/powershell/profile.ps1 in this repo carries the same block and must
# stay identical: it is what a full restore writes as the initial $PROFILE.
#
# To change how either account launches, edit THIS file, run repair.ps1 -Force,
# and mirror the block into terminal/powershell/profile.ps1.

#region profile-block
# Personal account, xhigh effort by default (max is reserved for extreme cases).
# The machine's ambient default (User-scope CLAUDE_CONFIG_DIR) points at
# ~/.claude-pegasuz, so reaching the personal account requires typing `claude`:
# the function CLEARS the variable, scoped to this invocation, and Claude then
# resolves its true default — ~/.claude for config, ~/.claude.json for state.
# Never pin the variable TO ~/.claude instead of clearing it: a set variable
# relocates .claude.json inside the dir, and the personal one lives at the
# home root.
function claude {
    $saved = $env:CLAUDE_CONFIG_DIR
    Remove-Item Env:\CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
    try {
        & claude.exe --effort xhigh --dangerously-skip-permissions @args
    } finally {
        if ($null -ne $saved) { $env:CLAUDE_CONFIG_DIR = $saved }
    }
}

# Second account — also where the ambient default already points, so Orca, its
# agents, and any bare claude.exe land here without this function. Typing
# `pegasuz` still matters for the health checks: isolation is CLAUDE_CONFIG_DIR
# only; the binary is shared, so versions cannot diverge. plugins/ and skills/
# are junctions into ~/.claude and never break; settings.json and CLAUDE.md are
# hardlinks, which replace-on-write silently breaks, so they are re-checked
# here on every launch. ~/.claude wins.
function pegasuz {
    $source = Join-Path $env:USERPROFILE '.claude'
    $config = Join-Path $env:USERPROFILE '.claude-pegasuz'

    if (-not (Test-Path -LiteralPath $config)) {
        New-Item -ItemType Directory -Path $config -Force | Out-Null
    }

    foreach ($name in 'settings.json', 'CLAUDE.md') {
        $from = Join-Path $source $name
        $link = Join-Path $config $name
        if (-not (Test-Path -LiteralPath $from)) { continue }

        $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        if ($item.LinkType -eq 'HardLink') { continue }

        if ($item) { Remove-Item -LiteralPath $link -Force }
        New-Item -ItemType HardLink -Path $link -Value $from | Out-Null
        Write-Host "pegasuz: re-linked $name from $source" -ForegroundColor Yellow
    }

    # Scoped to the child process, and the previous value is restored rather
    # than removed: in a console that inherited the ambient default (an Orca
    # terminal), a later bare claude.exe must keep resolving to pegasuz.
    $saved = $env:CLAUDE_CONFIG_DIR
    $env:CLAUDE_CONFIG_DIR = $config
    try {
        & claude.exe --effort xhigh --dangerously-skip-permissions @args
    } finally {
        if ($null -ne $saved) { $env:CLAUDE_CONFIG_DIR = $saved }
        else { Remove-Item Env:\CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    }
}
#endregion
