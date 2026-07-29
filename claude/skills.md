# Skills

The policy is intentionally mechanical:

| Location | Policy |
| --- | --- |
| `~/.claude/skills/` | `user-invocable-only` |
| Installed Claude plugin | Unchanged |

`claude/install.ps1` discovers the user skill directory at run time and generates
`skillOverrides`; this repository does not carry a list of skill names. New user-directory
skills therefore stay available through explicit invocation without filling every session's
automatic skill listing.

Claude Code documents that plugin skills are not affected by `skillOverrides`, including
when a plugin and the user directory contain the same skill name. No cache inspection or
name exception is needed.

Use `/context` in Claude Code when you want to inspect the actual context cost. Counts and
usage snapshots are deliberately not stored here because they become historical almost
immediately.
