# Claude Code

This folder owns the user-level Claude Code configuration that should survive a Windows
reinstall. It contains current desired state, not an inventory of old plugins, skills, or
experiments.

## Apply it

```powershell
pwsh claude\install.ps1
pwsh claude\install.ps1 -WhatIfOnly
pwsh claude\install.ps1 -Secrets
```

The normal run requires the native Claude Code CLI, registers the declared marketplaces,
installs or enables every desired plugin, installs the global instructions, reconciles the
repo-owned global rules directory, and merges `settings.json` into
`~/.claude/settings.json`. `-Secrets` additionally syncs the MCP servers declared in
`mcp.template.json` through Claude's user-scope MCP CLI.

Before replacing a live file, the shared installer stores its original path under one
run-specific directory in `~/.workstation-backup/`. The settings result is checked with
`claude doctor`; a non-zero result makes the step fail.

## Files and ownership

| File | Responsibility |
| --- | --- |
| `CLAUDE.md` | Short global user instructions |
| `settings.json` | Repo-owned settings, permissions, and desired plugins |
| `marketplaces.json` | Marketplace names and reproducible GitHub sources |
| `rules/common/` | Complete set of repo-owned global rules; currently empty |
| `mcp.template.json` | Managed MCP definitions and names of external MCP integrations |
| `plugins.md` | Current plugin and MCP architecture |
| `skills.md` | Current policy for user-directory and plugin skills |

Repo settings override the same keys in the live file. Other valid live keys are preserved.
Legacy hook structures that cause Claude to reject the entire file are discarded, while the
complete original file remains in the run backup.

## OMC

`oh-my-claude-sisyphus` is installed as an npm global, but its setup remains explicit:

```powershell
omc-setup
pwsh claude\install.ps1
```

OMC owns the block between `OMC:START` and `OMC:END` in the live `~/.claude/CLAUDE.md`.
The installer preserves that live generated block and places the concise repo-owned text
before it. The generated block is intentionally not frozen in this repository.

## Secrets and MCP

Copy `secrets/.env.example` to `secrets/.env`, fill every required value, then run with
`-Secrets`. The installer validates all placeholders before changing anything and uses:

```powershell
claude mcp add-json --scope user
```

Current Claude Code stores those servers in `~/.claude.json`; the repo never writes the old
`~/.claude/mcp-configs/mcp-servers.json` location. If that obsolete file exists after a
successful migration, it is backed up and removed.

`pencil` is listed as externally managed because Pencil Desktop registers its own local
server. MCPs supplied by enabled Claude plugins are also kept out of the user-scope list to
avoid shadowing plugin-owned definitions.

GitHub, fal.ai, and Browserbase use their current hosted HTTP MCP endpoints. Their
credentials remain local in `secrets/.env` and in Claude's user-scope configuration; the
repository contains placeholders only.

## What stays manual

| What | How |
| --- | --- |
| Claude login | Run `claude` and complete OAuth in the browser |
| MCP credentials | Create `secrets/.env` from the example, then use `-Secrets` |
| OMC setup | Run `omc-setup`, then re-run this installer |
| Pencil MCP | Install and start Pencil Desktop; it owns the connection |
