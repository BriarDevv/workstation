# accounts

The dual Claude Code account system: one binary, two accounts, deterministic
billing. The full design and its failure modes live in
`skills/claude-dual-account-setup/SKILL.md` — this folder is its desired
state, restored by `install.ps1`.

## The identity rule

The command decides, and everything else is pegasuz:

| How Claude is launched            | Config dir          | Bills    |
| --------------------------------- | ------------------- | -------- |
| `claude` (function)               | `~/.claude`         | personal |
| `pegasuz` (function)              | `~/.claude-pegasuz` | pegasuz  |
| Orca and the agents it spawns     | `~/.claude-pegasuz` | pegasuz  |
| bare `claude.exe`, any other tool | `~/.claude-pegasuz` | pegasuz  |

A User-scope `CLAUDE_CONFIG_DIR` pins the ambient default to the pegasuz dir.
Any mistake or unknown launcher burns the pegasuz plan, never the personal one.

## What install.ps1 restores

| Piece                                   | Mechanism                                        |
| --------------------------------------- | ------------------------------------------------ |
| The skill (docs + repair + functions)   | Junction into `~/.claude/skills`                 |
| `CLAUDE_CONFIG_DIR` (User scope)        | `repair.ps1` sets it to `~/.claude-pegasuz`      |
| plugins/skills junctions, hardlinks     | `repair.ps1`, `~/.claude` canonical              |
| `claude` / `pegasuz` in `$PROFILE`      | `repair.ps1 -Force` from `profile-functions.ps1` |
| `~/.config/hud/accounts.json` (HUD chip)| From `secrets/hud-accounts.json`; scheme-slot color names resolved against the active terminal scheme |

`terminal/powershell/profile.ps1` carries the same marked block as
`profile-functions.ps1` (the terminal step writes the initial `$PROFILE`);
when changing a launcher, edit both — the SKILL.md's Repair section says how.

## What stays manual

| What | How |
| --- | --- |
| Account logins | Run `claude` and `pegasuz` once each and complete `/login` |
| Orca restart | Restart Orca after the first install so it inherits the ambient default |
| HUD account emails | Copy `accounts/hud-accounts.example.json` to `secrets/hud-accounts.json` and fill it in |
