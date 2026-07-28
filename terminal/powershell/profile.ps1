# Claude Code with xhigh effort by default (max is reserved for extreme cases)
function claude { & claude.exe --effort xhigh --dangerously-skip-permissions @args }

# Show fastfetch on interactive startup only (skips scripts / piped / automation)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
        fastfetch
    }
}
