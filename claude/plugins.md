# Plugins and MCP

## Plugins

Installed with `claude plugin install <name>`.

| Plugin                                        | Uses  | Keep              |
| --------------------------------------------- | ----- | ----------------- |
| `playwright@claude-plugins-official`          | 4,432 | ✅                |
| `superpowers@claude-plugins-official`         | 324   | ✅                |
| `chrome-devtools-mcp@chrome-devtools-plugins` | 47    | ✅                |
| `frontend-design@claude-plugins-official`     | 13    | ✅                |
| `context7@claude-plugins-official`            | 7     | ✅                |
| `github@claude-plugins-official`              | **0** | ❌ don't reinstall |

`github` sat installed for 46 days without a single call. Its `lastUsedAt` looked recent,
but that's the install date, not a usage date.

---

## MCP

You had **27 servers** configured in `mcp-configs/mcp-servers.json` plus 2 in
`~/.claude.json`. Four of them were used in 46 days.

MCP tools are **deferred** — descriptions don't load until they're needed — so extra
servers cost no tokens. They do cost startup time, maintenance, and key exposure.

### The ones that stay

| Server                | Key                            | Measured use             |
| --------------------- | ------------------------------ | ------------------------ |
| `chrome-devtools`     | —                              | 47 (via the plugin)      |
| `pencil`              | —                              | 11                       |
| `context7`            | —                              | 7                        |
| `playwright`          | —                              | via plugin               |
| `filesystem`          | —                              | scoped to `Desktop`. `Laragon\www` was dropped 2026-07-28 |
| `sequential-thinking` | —                              | —                        |
| `memory`              | —                              | —                        |
| `supabase`            | —                              | —                        |
| `github`              | `GITHUB_PERSONAL_ACCESS_TOKEN` | —                        |
| `exa-web-search`      | `EXA_API_KEY`                  | —                        |
| `firecrawl`           | `FIRECRAWL_API_KEY`            | —                        |
| `jira`                | `JIRA_*`                       | —                        |
| `confluence`          | `CONFLUENCE_*`                 | —                        |
| `fal-ai`              | `FAL_KEY`                      | —                        |
| `browserbase`         | `BROWSERBASE_API_KEY`          | —                        |

> ⚠️ There was a user-scope `chrome-devtools` **on top of** the plugin, doing the same
> thing. The plugin's got used 3x more (47 vs 14). Only one survives.

### The ones I dropped

`omega-memory`, `vercel`, `railway`, `cloudflare-docs`, `cloudflare-workers-builds`,
`cloudflare-workers-bindings`, `cloudflare-observability`, `clickhouse`, `magic`,
`browser-use`, `devfleet`, `token-optimizer`, `laraplugins`, `evalview`.

Zero recorded use. If you need one back, it's in the git history.

---

## claude.ai connectors

| Connector       | Uses | Keep |
| --------------- | ---- | ---- |
| Gmail           | 1    | ✅   |
| Canva           | 0    | ❌   |
| Google Calendar | 0    | ❌   |
| Google Drive    | 0    | ❌   |

These are **not** configured from the repo — you connect and disconnect them on claude.ai.

---

## 🔑 The keys

The 8 API keys that were sitting **in plaintext** in `mcp-servers.json`:

`GITHUB_PERSONAL_ACCESS_TOKEN` · `EXA_API_KEY` · `FIRECRAWL_API_KEY` · `JIRA_API_TOKEN` ·
`CONFLUENCE_API_TOKEN` · `FAL_KEY` · `BROWSERBASE_API_KEY` · `OPENAI_API_KEY`

That file is in `.gitignore` and never enters the repo. What lives here is
`mcp.template.json` with `${VAR}` placeholders, and `secrets/.env.example` documenting
where to regenerate each one.

> If that file was ever pushed to a public repo with the keys in it, **rotate all of them**.
