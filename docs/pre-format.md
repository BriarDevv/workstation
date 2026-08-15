# Pre-format checklist

Complete this immediately before resetting or erasing Windows. Nothing else on this machine
needs to be preserved; the only required recovery source is the published repository.

## Windows and recovery

- Confirm that Settings → System → Activation reports Windows 11 Pro as activated.
- Confirm access to the GitHub and Claude accounts used by the restore.

## Repositories and local work

Inspect this repository's `git status`, local commits and untracked files. Commit and push
the final desired state. Files elsewhere on this machine are intentionally disposable.

## Verify before erasing

Clone `bygama/workstation` into a temporary directory and confirm the clean clone contains
the latest commit, `docs/post-format.md`, `tests/`, and `windows/audit.ps1`. Only start
**Reset this PC** after that clone succeeds.
