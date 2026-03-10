# Rocky — Claude Code Instructions

## Project overview

Rocky is a CLI time tracking tool built in Swift. Read the `RockyDocs/` directory for full design documentation before making any changes.

## Ground rules

- **Do not deviate from the design docs** in `RockyDocs/` without explicitly flagging it and getting confirmation
- **Do not redesign decided features** — all decisions in `RockyDocs/DECISIONS.md` are final
- **Do not add dependencies** beyond what is listed in `RockyDocs/OVERVIEW.md` without asking first
- **Do not rename commands, flags, or output fields** — these are locked in `RockyDocs/COMMANDS.md` and `RockyDocs/OUTPUT.md`
- **Do not change the database schema** without flagging it — schema is locked in `RockyDocs/SCHEMA.md`

## Repo structure

Single Swift package with multiple targets:

```
RockyCLI/
├── Package.swift
├── CLAUDE.md               ← you are here
├── RockyDocs/              ← design documentation (read only)
├── Sources/
│   ├── RockyCore/          ← library target (business logic, database, models, services)
│   ├── App/                ← executable target (CLI commands, output formatting)
│   └── VersionGen/         ← build tool (generates Version.swift from git tag)
├── Tests/
│   ├── RockyCoreTests/
│   └── AppTests/
└── Plugins/
    └── VersionPlugin/
```

## Target rules

### RockyCore (library)

- **No CLI imports** — do not import ArgumentParser or any CLI-specific package
- **No UI imports** — do not import any UI framework
- **No print statements** — RockyCore never writes to stdout
- **Raw SQL only** — use sqlite-nio directly, no ORM, no query builders
- **Async/await throughout** — all database calls must be async
- **Errors must throw** — never silently swallow errors

### App (executable)

- **No business logic** — App only calls RockyCore and formats results
- **No direct database access** — never import sqlite-nio or touch the database
- **Output must match `RockyDocs/OUTPUT.md` exactly** — column alignment, divider characters, duration format
- **Use `▶` (U+25B6) for active timers** — two spaces `  ` for inactive rows
- **Use `─` (U+2500) for divider lines** — not `-` (hyphen)
- **Duration format is `Xh Ym`** — e.g. `2h 30m`, `0h 45m`, `1h 00m`
- **24h time format** — `HH:MM`, local timezone
- **Never exit with code 0 on error** — use `exit(1)` or throw

## What to work on

- All new features go through `RockyCore` first, then surfaced in `App`
- Database location: `~/.rocky/rocky.db` — create `~/.rocky/` if it does not exist

## GitHub workflow

Follow this workflow for every piece of work:

1. **Create an issue first** — before writing any code, create a GitHub issue describing what you're about to implement
2. **Work in a branch** — create a branch named after the issue, e.g. `feature/1-rocky-start`
3. **Keep PRs small and focused** — one feature or component per PR
4. **Open a PR referencing the issue** — PR description should reference the issue number (e.g. `Closes #1`)
5. **Never push directly to main** — all changes go through a PR

## When in doubt

Read `RockyDocs/DECISIONS.md` first. If the answer isn't there, ask before implementing.
