# Global Claude Code instructions

These instructions apply across projects. Keep project-specific commands, architecture and
quality gates in that project's own `CLAUDE.md`.

## Working style

- Work directly unless the user requests delegation or an invoked workflow requires it.
- Inspect the repository before planning a substantial change.
- Prefer evidence from the code, command output and primary documentation over assumptions.
- Make the smallest coherent change that satisfies the request.
- Preserve unrelated user changes in a dirty worktree.

## Safety

- Never expose or commit credentials, tokens, private keys or populated `.env` files.
- Resolve exact targets before destructive filesystem or git operations.
- Do not claim success without running the relevant verification.

## Completion

Report what changed, what verification passed, and any remaining manual or blocked work.

The OMC-generated block is deliberately not stored here. `claude/install.ps1` preserves the
current live block between `OMC:START` and `OMC:END`, so updating OMC cannot leave this repo
holding an obsolete generated copy.
