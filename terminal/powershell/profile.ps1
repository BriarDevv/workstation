# >>> claude-dual-account-setup >>>
# Claude Code with xhigh effort by default (max is reserved for extreme cases)
function claude { & claude.exe --effort xhigh --dangerously-skip-permissions @args }

# Second account. Isolation is CLAUDE_CONFIG_DIR only; the binary is shared, so
# versions cannot diverge. plugins/ and skills/ are junctions into ~/.claude and
# never break; settings.json and CLAUDE.md are hardlinks, which replace-on-write
# silently breaks, so they are re-checked here on every launch. ~/.claude wins.
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

    # Scoped to the child process: a plain `claude` in this same console must
    # keep using ~/.claude.
    $env:CLAUDE_CONFIG_DIR = $config
    try {
        & claude.exe --effort xhigh --dangerously-skip-permissions @args
    } finally {
        Remove-Item Env:\CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
    }
}
# <<< claude-dual-account-setup <<<

# Show fastfetch on interactive startup only (skips scripts / piped / automation)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
        fastfetch
    }
}
