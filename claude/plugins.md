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
| `pencil`              | —                              | 11                       |
| `filesystem`          | —                              | scoped to `repos\` via `layout/LAYOUT.md` |
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

### The three that are deliberately absent

`context7`, `playwright` and `chrome-devtools` **arrive as plugins** and are not in
`mcp.template.json`. Listing them in both places starts the same server twice.

Counted over the 30 days to 2026-07-28 — real tool invocations, 48 transcripts, 369k lines:

| Server            | Loose server | Plugin    |
| ----------------- | -----------: | --------: |
| `playwright`      |        **0** | **3,037** |
| `context7`        |        **0** |         1 |
| `chrome-devtools` |           12 |        47 |

The playwright row is the argument. It isn't that the plugin is more popular — the loose
server was **never called once**, while still starting an `npx` process every session.

The plugin also wins on a second count: it ships **skills** next to its tools, so the model
gets told when to use them. A loose server hands over 29 tools and no guidance.

> Numbers here are only reproducible inside their window. Transcripts are pruned after
> ~30 days (`cleanupPeriodDays`), so re-measuring later gives smaller counts for the same
> history — not a wrong table. Always write the window down next to the number.

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
