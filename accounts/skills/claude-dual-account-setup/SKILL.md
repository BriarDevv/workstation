---
name: claude-dual-account-setup
description: Use when questions come up about this machine's two Claude Code accounts (the personal `claude` and `pegasuz`), which config they share and which they don't, why settings.json or CLAUDE.md drifted or reverted between the two, why a model or plugin change did not carry over, when the `pegasuz` or `claude` command is missing or "not recognized", when something breaks right after a Claude Code update, when the wrong account seems to be billed or the HUD account chip turns red, when Orca's account switcher or its credential swapping is involved, or when a junction, hardlink, or the CLAUDE_CONFIG_DIR ambient default needs verifying or repairing.
---

# Claude Dual Account Setup

## Overview

This machine runs two Claude Code accounts off one binary. Isolation comes from
`CLAUDE_CONFIG_DIR`, which decides where credentials, sessions and usage live.
Everything meant to be shared is shared through filesystem links, not copies —
so there is one physical file, not two that need syncing.

The identity rule is: **the command decides, and everything else is pegasuz.**
A User-scope environment variable pins the machine's ambient default to the
pegasuz dir, so the only path to the personal account is typing `claude` in a
shell that loaded `$PROFILE`:

| How Claude is launched            | Config dir              | Bills          |
| --------------------------------- | ----------------------- | -------------- |
| `claude` (function)               | `~/.claude`             | personal       |
| `pegasuz` (function)              | `~/.claude-pegasuz`     | pegasuz        |
| Orca and the agents it spawns     | `~/.claude-pegasuz`     | pegasuz*       |
| bare `claude.exe`, any other tool | `~/.claude-pegasuz`     | pegasuz        |

\* or whatever account Orca's own switcher has placed in that dir — see the
Orca section.

The asymmetry is deliberate: any mistake, unknown launcher, or third-party
integration burns the pegasuz plan, never the personal one. The personal
account cannot be reached by accident.

The ambient default is `CLAUDE_CONFIG_DIR` at **User scope** pointing at
`~/.claude-pegasuz`. The `claude` function *clears* the variable (scoped,
restored after); it must never *set* it to `~/.claude` instead — a set
variable relocates `.claude.json` inside the dir, and the personal one lives
at `~/.claude.json` in the home root, not inside `~/.claude`. Only `pegasuz`
keeps its `.claude.json` inside its config dir.

Both functions are PowerShell functions in `$PROFILE`, inside a **marked
block** copied from the canonical `profile-functions.ps1` in this skill
directory:

```powershell
# >>> claude-dual-account-setup >>>
...both functions...
# <<< claude-dual-account-setup <<<
```

`$PROFILE` is a plain file outside both config dirs, so no link protects it.
If a function is missing there, *that* command disappears while the links stay
perfectly healthy. Symptom: `pegasuz` (or `claude`) reports "is not recognized
as a name of a cmdlet". `repair.ps1` restores the block. A function that works
right now proves nothing about the file — it may have been defined live in a
console and never persisted (that loss happened once, 2026-08-10/11). Confirm
both, separately:

```powershell
Get-Command pegasuz -ErrorAction SilentlyContinue   # loaded in THIS session?
Select-String -Path $PROFILE -Pattern 'function pegasuz'  # persisted on disk?
```

This skill lives in the `workstation` repo (`accounts/skills/…`) and is
junction-linked into `~/.claude/skills` by `accounts/install.ps1`, which also
restores the env var, the links, and the HUD account mapping on a fresh
machine. Edit it there so git carries every change.

The binary at `~/.local/bin/claude.exe` and its installer state under
`~/.local/share/claude` and `~/.local/state/claude` sit outside both config
dirs, so updates are always shared. Versions cannot diverge.

## What Is Shared

| Entry           | Link type | Direction     |
| --------------- | --------- | ------------- |
| `plugins/`      | Junction  | bidirectional |
| `skills/`       | Junction  | bidirectional |
| `settings.json` | HardLink  | bidirectional |
| `CLAUDE.md`     | HardLink  | bidirectional |

Everything else is per-account by design: `.credentials.json`, `.claude.json`,
`sessions/`, `projects/`, `history.jsonl`, `file-history/`, `backups/`,
`tasks/`, `jobs/`, `teams/` and the caches. Sessions and history never cross
accounts: each account resumes only its own conversations, even in the same
folder.

Neither symlinks nor `New-Item -ItemType SymbolicLink` are used, because this
machine has no admin rights and no Developer Mode. Junctions (directories) and
hardlinks (files) are the two link types that work unprivileged.

## Why Config Silently Drifts

A hardlink is two directory entries pointing at one file. It survives in-place
edits. It does **not** survive replace-on-write — an app that writes a temp file
and renames it over the target creates a *new* file, leaving the other name
pointing at the old content. Both entries then report an empty `LinkType`.

The most frequent trigger is Claude Code itself: changing a setting from
inside a session (`/config`, `/model`, `/effort`, toggling a plugin) rewrites
`settings.json`, which breaks the link on the spot. So the link tends to break
precisely when you change something you *wanted* both accounts to see.

Symptom: a change made in one account is invisible to the other, or reverts.

The `pegasuz` function re-checks both hardlinks on every launch and re-links
from `~/.claude` when broken, printing a yellow notice. So the drift window is
"until the next `pegasuz` launch", and `~/.claude` wins. Consequence of that
direction: **make config changes from personal sessions.** A `/config` change
made from the pegasuz side breaks the link and gets discarded at the next
re-link. The same applies to anything Orca writes into settings.json now that
Orca operates in the pegasuz dir — if Orca updates its hooks and the change
must survive, mirror it into `~/.claude`.

## Orca

Orca resolves every Claude path through `CLAUDE_CONFIG_DIR` (its
`ClaudeRuntimePathResolver` honors the inherited variable), so with the
ambient default in place Orca lives entirely inside `~/.claude-pegasuz`:
config, credentials, and the agents it spawns. Restart Orca after changing the
variable — processes keep the environment they started with.

**Orca's managed accounts swap credentials in place.** When its account
switcher activates a managed account, Orca snapshots the dir's current
credential to `%APPDATA%/orca/claude-runtime-auth/system-default-auth.json`
and writes the managed account's credential over `.credentials.json`; it
restores the snapshot when the selection clears (pane closed, switched back).
Two consequences:

- In Orca's panel, "System default" means "whatever credential lives in the
  ambient-default dir" — the pegasuz account, here. Selecting a managed
  account changes which account *the pegasuz slot* bills; it can never touch
  `~/.claude`. Before the ambient default existed, that same swap ran against
  `~/.claude` and silently billed the wrong account — that is the incident
  this design exists to prevent (2026-08-12).
- A session holds the token it started with: after switching accounts in
  Orca, restart its live Claude terminals (Orca itself says so in the panel).

**Orca's hooks are shared, and cannot not be.** Its installer wrote its hook
events into the shared `settings.json`, so they fire in both accounts'
sessions. Orca's own state under `~/.orca` and `%APPDATA%/orca` sits outside
both config dirs. `settings.json.bak` next to settings.json is that
installer's backup (pre-Orca settings), not Claude Code's.

**Agents spawned through the orca CLI follow the parent rule, not the ambient
default.** Orca terminals are pwsh with `$PROFILE` loaded, so the spawn
command selects the account per terminal:
`orca terminal create --worktree <sel> --command "claude"` bills the personal
account, `--command "pegasuz"` bills pegasuz — concurrently, per worktree,
with no global switching. A session composing that spawn inherits its own
account by detection: `CLAUDE_CONFIG_DIR` pointing at `.claude-pegasuz` means
pegasuz, unset means personal (the global CLAUDE.md carries this rule, so
every session applies it). The ambient default only decides the no-parent
cases: Orca's own UI spawns, automations, and bare `claude.exe`.

**Orca's terminal PTYs live in `orca-terminal-daemon`, a separate process
that survives app restarts.** Environment changes (the ambient default above
all) reach new terminals only after THAT process restarts too — quit Orca
fully, confirm `orca-terminal-daemon` is gone (`Get-Process`), then relaunch.
An app-only restart leaves terminals spawning with the old environment.

## The HUD Account Chip

The statusline (hud repo, `src/claude/statusline.mjs`) renders an account chip
that identifies the **credential**, not the folder: token hash → email via the
OAuth profile endpoint, cached per config dir and re-checked on every refresh,
so a swap under a live session shows within a minute. The mapping in
`~/.config/hud/accounts.json` (local only; restored from
`secrets/hud-accounts.json` by `accounts/install.ps1`, colors resolved from
the active terminal scheme) gives each account its label and color and
declares each dir's owning account. **A red chip with `!` means a foreign
credential sits in an owned slot** — exactly the swap-gone-wrong case; run
`repair.ps1 -WhatIf` and check the Orca panel when you see it.

## What a Claude Code Update Does

An update is a non-event for this setup. The updater only touches paths that
sit outside both config dirs:

| Path                                        | What the update does                       |
| ------------------------------------------- | ------------------------------------------ |
| `~/.local/share/claude/versions/<version>`  | Downloads the new build and keeps it       |
| `~/.local/bin/claude.exe`                   | Overwritten with a **copy** of that build  |
| `~/.local/state/claude/locks`               | Update lock, so both accounts never race   |

It does **not** touch `$PROFILE`, the junctions, the hardlinks, or the env
var. If something broke right after an update, compare mtimes before assuming
causation. Two consequences worth knowing:

**The update record is per-account, even though the binary is not.** Whichever
account is running performs the upgrade, and only that account writes
`.last-update-result.json`. The two files legitimately disagree; that is the
record diverging, not the binary. Do not "fix" this.

**Old versions accumulate and are never pruned.** Each build is ~280 MB and
stays in `versions/` forever. Check and prune when disk gets tight, keeping
the current version (`claude.exe --version`) and ideally the previous one:

```powershell
Get-ChildItem "$env:USERPROFILE\.local\share\claude\versions" |
  Sort-Object LastWriteTime |
  Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB)}}, LastWriteTime
```

## Verify

```powershell
# Links: Junction for plugins/skills, HardLink for settings.json/CLAUDE.md.
# An empty LinkType on a file means broken.
Get-ChildItem "$env:USERPROFILE\.claude-pegasuz" -Force |
  Select-Object Name, LinkType, Target

# Ambient default: must print the pegasuz dir.
[Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR', 'User')

# Commands: on disk and in a fresh session, not just this console.
Select-String -Path $PROFILE -Pattern 'claude-dual-account-setup'
pwsh -Command "Get-Command claude, pegasuz -CommandType Function"
```

Or just run `repair.ps1 -WhatIf`, which reports on everything and changes
nothing. The live billing identity of any open session is on its HUD chip.

## Repair

Run `repair.ps1` from this skill directory. It is idempotent and safe to run
any time; it takes `~/.claude` as canonical and reports what it changed:

| Checks                            | Canonical source          | On failure                          |
| --------------------------------- | ------------------------- | ----------------------------------- |
| `CLAUDE_CONFIG_DIR` (User scope)  | `~/.claude-pegasuz`       | Re-set; restart Orca to inherit it   |
| `plugins/`, `skills/` junctions   | `~/.claude`               | Re-created                          |
| `settings.json`, `CLAUDE.md`      | `~/.claude`               | Re-linked, `~/.claude` content wins  |
| `$PROFILE` marked block           | `profile-functions.ps1`   | Re-inserted; drift only reported     |

A missing block is restored silently. A block that *exists* but differs from
`profile-functions.ps1` is only reported — resolve with `repair.ps1 -Force`
(canonical wins) or copy your version back into `profile-functions.ps1` **and**
`terminal/powershell/profile.ps1` so the restore path carries it too.

Repairing the profile only changes the file. Open a new console or run
`. $PROFILE` for the current session to pick it up.

## Common Mistakes

| Mistake                                                | Result                                                                                         |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| Expecting bare `claude.exe` to bill the personal account | The ambient default routes it to pegasuz. Only the `claude` function reaches `~/.claude`.      |
| Pinning `CLAUDE_CONFIG_DIR` to `~/.claude` in the function | Relocates `.claude.json` into the dir; the personal state lives at `~/.claude.json`. Clear it. |
| Launching Orca before the env var existed in its environment | Orca falls back to `~/.claude` and can swap the personal credential. Restart Orca; check the HUD chip. |
| Switching accounts by re-logging inside a session      | Rewrites that dir's credential in place. Switching accounts = switching commands (or Orca's panel, which only governs the pegasuz slot). |
| Editing `settings.json` expecting both to update always | True only while the hardlink holds. Verify after any external writer touches it.                |
| Changing config from a pegasuz/Orca session            | Breaks the hardlink and the change is discarded at the next re-link. Change config from personal sessions. |
| Expecting the last-used model to carry across accounts  | It lives in `.claude.json` (`lastModelUsage`, per project), which is deliberately per-account.  |
| Pinning `model` in `settings.json`                      | Overrides last-used-model for *both* accounts, since the file is shared.                        |
| Deleting `~/.claude-pegasuz` to "reset"                 | Removes the junctions too, and orphans the ambient default. Run `repair.ps1`.                   |
| Expecting sessions or history to be shared              | They are not. Resuming a conversation only works within the account that created it.            |
| Blaming an update for a broken link or a lost command   | Updates touch nothing under either config dir or `$PROFILE`. Check mtimes before assuming.      |
| Defining a function in the console and moving on        | It works until the console closes. Persist it, then re-check in a *new* session.                |
| Editing `$PROFILE` (or the skill copy alone) to change a launcher | Three copies must agree: `profile-functions.ps1`, `terminal/powershell/profile.ps1`, `$PROFILE`. Edit the canonical, `repair.ps1 -Force`, mirror the terminal copy. |
| Keeping a loose `function pegasuz` outside the markers  | The last definition parsed wins, so it silently overrides the managed one. `repair.ps1` warns.   |
| Reading `settings.json.bak` as Claude Code's own backup | It is Orca's installer backup: the pre-Orca settings, no hooks in it.                           |
| Looking for the personal `.claude.json` inside `~/.claude` | It is at `~/.claude.json`. Only `pegasuz` keeps it inside its config dir.                    |
| Trusting `.claude.json`'s `oauthAccount` as the live identity | It records the last login, not the current credential; Orca's swap does not update it. The HUD chip queries the credential itself. |
