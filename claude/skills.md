# Skills

User skills come from one place: `repos\mine\Context-Engineering\skills\`, junction-linked
into `~/.claude/skills/` by `claude/install.ps1`. This repo carries no skill content and no
skill list — the link step is declarative over whatever that repo contains.

| Location | Policy |
| --- | --- |
| `~/.claude/skills/` | Junctions into Context-Engineering; load normally (auto-trigger by description) |
| Installed Claude plugin skills | Unchanged |

No `skillOverrides` are generated anymore. The previous `user-invocable-only` policy
existed to keep ~37 OMC skills out of the automatic listing; the current skills are few and
written for automatic triggering, so hiding them would defeat their design.

Use `/context` in Claude Code to inspect the actual context cost when the skill set grows.
