# Security Policy

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/bygama/workstation/security/advisories/new).
Do not open public issues for security problems.

You can expect an acknowledgment within a week.

## Scope

Supported: the `main` branch. Note: this repo intentionally ships no secrets —
only `secrets/.env.example` — and its installers write user-level config with
run-scoped backups. If you find anything that could leak a credential into
git or into a world-readable location, that is exactly what to report.
