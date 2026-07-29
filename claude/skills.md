# Skills

**The rule: a skill in `~/.claude/skills/` is off. A skill from a plugin is on.**

That's the whole policy, and it's a rule rather than a list on purpose — see below.

---

## Why

Every skill's name and description loads **in full, in every session, before you type a
word.** Measured 2026-07-27: 186 installed skills cost ~9,611 estimated tokens against a
healthy budget of ~2,000. Claude Code caps that listing at a fraction of the context window
(`skillListingBudgetFraction`, 1% by default) and starts shortening descriptions when you go
over — so past the budget you don't just pay, you lose the descriptions that make the listing
useful in the first place.

The two that get used — `superpowers` and `frontend-design` — **both come from plugins**, and
plugin skills aren't affected by this. So the folder can go quiet without losing anything.

---

## How it's applied

`install.ps1` reads the disk at run time and writes `skillOverrides` into
`~/.claude/settings.json`:

| Where the skill lives | What it gets |
| --------------------- | ------------- |
| `~/.claude/skills/` | `user-invocable-only` |
| A plugin | untouched |
| `~/.claude/skills/` **and** a plugin share a name | untouched — the plugin wins |

`user-invocable-only` and not `off`: both cost the model zero tokens, but this one keeps
`/skill-name` working. Nothing is lost, so nothing has to be decided in advance.

The last row is a real case, not a hypothetical: `frontend-design` exists in both places
today. Since `skillOverrides` is keyed by name, disabling the folder copy could take the
plugin copy with it — so any name a plugin also provides is left alone.

---

## Why a rule and not a list

The obvious version of this file is two tables: the ones that stay, the ones that go. The
second table would be **176 names of things you don't want**, and the root `CLAUDE.md` is
explicit that a repo carrying a list of what its owner rejected ships its own contamination.

It's also unmaintainable. That list is right until the next `npm i -g` pulls in skills, and
then it's silently incomplete — a skill lands in the folder, isn't in the reject list, and
loads into every session with nobody noticing.

Reading the disk has neither problem. Install a plugin and its skills are protected
automatically; drop anything into `~/.claude/skills/` and it's quiet by default. Nothing in
this repo has to be edited either way.

---

## `~/.claude/.agents/skills/`

**34 more skills, 345 KB, 30 of them duplicates.** Verified they don't load into context:
disk clutter, not token cost. Safe to delete, and nothing here does it for you.

---

## How to re-measure

Counters live in `~/.claude.json`, field `skillUsage` — **lifetime**, never reset. For
plugins use `pluginUsage`, where `lastUsedAt` is stamped at install time and is only
trustworthy when `usageCount > 0`.

The real weight is `/context` inside a session. Everything else is an estimate.
