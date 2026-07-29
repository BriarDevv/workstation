# Plugins and MCP

`settings.json` is the source of truth for enabled Claude plugins, while
`marketplaces.json` records the marketplace sources needed to install them on a clean
machine. The installer reconciles both. The current set is:

| Plugin | Purpose |
| --- | --- |
| `frontend-design@claude-plugins-official` | Frontend design guidance |
| `context7@claude-plugins-official` | Library documentation and MCP tools |
| `chrome-devtools-mcp@chrome-devtools-plugins` | Browser inspection through DevTools |
| `superpowers@claude-plugins-official` | Structured development workflows |
| `playwright@claude-plugins-official` | Browser automation |

Check effective state rather than trusting the JSON alone:

```powershell
claude plugin list --json
claude mcp list
pwsh .\snapshot.ps1
```

Claude rejects an invalid user settings file as a whole. In that state the file can say a
plugin is enabled while `claude plugin list --json` correctly reports it disabled. Running
`claude/install.ps1` repairs supported settings and validates the result.

## MCP ownership

There are three non-overlapping sources:

| Source | Managed by |
| --- | --- |
| Plugin MCPs such as Context7, Playwright, and Chrome DevTools | `enabledPlugins` |
| Credentialed/general user servers | `mcp.template.json` plus `secrets/.env` |
| `pencil` | Pencil Desktop |

Do not also add a plugin-provided server at user scope. Claude resolves overlaps by scope,
with user scope taking precedence over plugin scope, so the loose definition shadows the
plugin-owned one and can drift away from plugin updates. `snapshot.ps1` detects matching
server names from effectively enabled plugin paths, not merely from cached plugin files.
