# Skills

Out of **186 skills** installed in `~/.claude/skills`, across **366 Claude Code startups**
between Feb and Jul 2026, you used **10**.

The other 176 aren't free: the skills listing (name + description of each one) loads
**in full, every session**. It cost **~9,611 estimated tokens** against a healthy budget
of ~2,000. Once you're over, the listing truncates and Claude picks worse.

---

## The ones that stay

| Skill             | Uses |
| ----------------- | ---- |
| `frontend-design` | 37   |
| `team`            | 6    |
| `omc-setup`       | 3    |
| `ai-slop-cleaner` | 2    |
| `find-skills`     | 2    |
| `ralph`           | 2    |
| `setup`           | 2    |
| `frontend-slides` | 1    |
| `github-ops`      | 1    |
| `omc-teams`       | 1    |

## The ones that don't

The remaining 176. They don't get deleted from disk — they get disabled through
`skillOverrides` in `settings.json`, so they're still there if you ever need one.

---

## `~/.claude/.agents/skills/`

There are **34 more skills** in there (30 duplicated from `skills/`, 345 KB). Verified
they **do not load** into context: disk clutter, not token cost. Safe to delete.

---

## How to re-measure this

The counters live in `~/.claude.json`, field `skillUsage`. They're **lifetime** counters
and never reset. For plugins check `pluginUsage`: `lastUsedAt` is stamped at install time,
so it's only trustworthy when `usageCount > 0`.

Verify the real weight with `/context` inside a session.
