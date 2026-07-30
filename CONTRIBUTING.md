# Contributing to workstation

## Workflow

- Branch from `main`: `feat/<topic>` or `fix/<topic>`.
- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`.

## Before opening a PR

- Parse every changed PowerShell file and run `pwsh ./tests/run.ps1` — all
  tests must pass.
- For a restore-path change, also run the relevant `-WhatIfOnly` command and
  confirm it makes no tracked or user-config writes.

## Merging

Rebase; keep `main` linear.
