# Claude Code

The folder that moves the most. Everything that makes Claude operate well, repo by repo.

---

## What's in here

| File                | What it is                                       | Loaded…                     |
| ------------------- | ------------------------------------------------ | --------------------------- |
| `CLAUDE.md`         | Global instructions                              | **Every session, always**   |
| `rules/common/*.md` | 10 rules: style, testing, security, git…         | **Every session, always**   |
| `settings.json`     | Model, permissions, plugins                      | At startup                  |
| `mcp.template.json` | MCP servers, with `${VAR}` instead of real keys  | At startup                  |
| `skills.md`         | Which skills to keep and which to drop           | Reference                   |
| `plugins.md`        | Which plugins to keep and which to drop          | Reference                   |

---

## The golden rule: context is finite

Everything in `CLAUDE.md` and `rules/` loads **in every session of every repo**, before
you type a single word. That's space the actual work doesn't get.

Measured 2026-07-27:

| What                            | Est. tokens per session |
| ------------------------------- | ----------------------- |
| Skills listing (186 installed)  | ~9,611                  |
| `rules/common/`                 | ~4,228                  |
| Commands listing (79)           | ~1,746                  |
| `CLAUDE.md`                     | ~802                    |
| **Total resident**              | **~16,400**             |

A healthy budget for the skills listing is ~2,000 tokens. It was **5.7x over**, which
makes the listing truncate and Claude pick the wrong skill.

**Hence:** only the 10 skills you actually use (`skills.md`), only `rules/common/` (not
the 12 per-language directories), and a curated `permissions.allow`.

Target after applying everything: **~3,700 tokens** (-77%).

---

## How to write these files well

From *The new rules of context engineering for Claude 5 models* (Thariq, Anthropic,
Jul 2026), applied to this repo:

**1. Judgment, not rules.** Claude 5 follows instructions very literally. An absolute rule
("ALWAYS use agent X") gets obeyed even when it makes no sense. Write the *when* and the
*why*, not just the *what*.

> This already bit us: `rules/common/` said "use code-reviewer immediately after writing
> code" and "STOP and use security-reviewer". Result: Claude spawned agents nobody asked
> for. Fixed — delegation is **opt-in** now.

**2. Design the interface, don't pile on examples.** If you need five examples to explain
something, the problem is how it's defined, not the lack of examples.

**3. Progressive disclosure.** Don't front-load everything. Give an index and let Claude
read the detail when it needs it. A skill that loads on demand beats 400 lines in
`CLAUDE.md`.

**4. Simple tools.** Short, unambiguous descriptions beat long ones that repeat warnings.

**5. Repo-specific content is the only thing that adds value.** Generic rules ("write
tests", "handle errors") Claude already knows — they just take up room. What it **can't**
guess is the shape of the repo it's standing in:

> which package a command has to be run from rather than the root · where the one
> exportable barrel file lives · which file a new handler belongs beside · whether
> migrations are generated or written by hand

Four lines of that beat ten generic rules. But they belong in a `CLAUDE.md` **inside that
repo**, never here — this file configures the machine, and a machine outlives any project
on it.

---

## Watch out for OMC

`oh-my-claude-sisyphus` (OMC) installs via npm and owns `~/.claude/CLAUDE.md` between
`OMC:START` / `OMC:END` markers, plus the hooks (`~/.claude/hooks/*.mjs`), the HUD and the
statusline.

> ⚠️ **Running `omc-setup` overwrites manual edits to `~/.claude/CLAUDE.md`.**
> That's why the good copy lives here. After any `omc-setup` or OMC update, re-run this
> folder's `install.ps1`.

---

## Secrets

`mcp.template.json` has `${VAR}` where the keys go. The resolved version
(`~/.claude/mcp-configs/mcp-servers.json`) **never** enters the repo.

```powershell
cp ..\secrets\.env.example ..\secrets\.env   # fill in the 11 keys
pwsh .\install.ps1 -Secrets                  # resolve the ${VAR} placeholders
```

---

## What stays manual

| What              | How                                                     |
| ----------------- | ------------------------------------------------------- |
| Claude login      | run `claude` → OAuth in the browser                     |
| The 11 API keys   | `secrets/.env`                                          |
| OMC               | `npm i -g oh-my-claude-sisyphus`, then `omc-setup`      |

---

## Hooks — measured performance

46 days, 360k transcript lines. Zero timeouts, but:

| Hook                          | n      | p50            | p95   | max        |
| ----------------------------- | ------ | -------------- | ----- | ---------- |
| `PreToolUse` on pencil tools  | 12     | **5,145 ms** ⚠️ | 5,150 | 5,150      |
| `Stop`                        | 2,560  | 298 ms         | 4,794 | **22,331** ⚠️ |
| `PreToolUse:Bash`             | 35,461 | 127 ms         | 225   | 10,631     |
| `PostToolUse:Edit`            | 20,909 | 129 ms         | 215   | 511        |

The pencil one charges you 5 seconds every time you touch a design tool. Worth narrowing
its matcher.
