# Rocky Platform — Conceptual Notes

Status: **Early brainstorming** — nothing here is finalized. This document captures ideas discussed so far.

## Motivation

- Sync time tracking data between devices
- On-the-go tracking, updating, stats, and dashboard access
- Team tracking is not a primary goal but could emerge as a byproduct

## Core Principle

Rocky CLI remains fully functional as a standalone offline tool. The platform backend is optional — expanded features when connected, zero loss of functionality without it.

## Architecture

### Repository Pattern

The CLI interacts with data through a repository abstraction. The repository decides where data comes from:

- **No backend configured:** Repository reads/writes directly to local SQLite. This is the current behavior.
- **Backend configured:** Repository talks to the backend API (source of truth), then stores the result in local SQLite as a cache.

The CLI layer never knows or cares which mode is active.

### Data Flow

```
No backend:
  CLI → Repository → SQLite (source of truth)

With backend:
  CLI → Repository → Backend API (source of truth) → cache to local SQLite
```

The backend is the source of truth when configured. The local SQLite database serves as a local cache of the backend state, useful for fast reads and potential offline access.

### OpenAPI as Contract

- An OpenAPI spec defines the canonical API surface
- The Hummingbird backend implements the spec
- The CLI conforms to the spec via a generated API client
- Both sides validate against the spec so they can't drift

### Public vs Private Specs

Multiple OpenAPI specs can coexist:

- **Public spec** — endpoints the CLI and third parties use (sessions, projects, dashboard, etc.)
- **Private spec** — internal/admin endpoints (user management, billing, infrastructure) that never leave the platform repo

The server implements both. The CLI only knows about the public spec.

## Repo Structure

### Current State

Everything lives in one repo (`Rocky`) with separate Swift packages for RockyCore, RockyCLI, and a Rocky.app stub. This repo is public.

### CLI Repo Consolidation

Rename the repo to `RockyCLI`. Remove the Rocky.app stub and consolidate into a single Swift package with multiple targets. Two naming options under consideration:

**Option A:**

```
RockyCLI/
├── Package.swift
├── CLAUDE.md
├── RockyDocs/
├── Sources/
│   ├── RockyCore/          ← library target (CLI's domain logic)
│   └── RockyCLI/           ← executable target, depends on RockyCore
└── Tests/
    ├── RockyCoreTests/
    └── RockyCLITests/
```

**Option B:**

```
RockyCLI/
├── Package.swift
├── CLAUDE.md
├── RockyDocs/
├── Sources/
│   ├── RockyCore/          ← library target (CLI's domain logic)
│   └── App/                ← executable target, depends on RockyCore
└── Tests/
    ├── RockyCoreTests/
    └── AppTests/
```

Option B avoids the nested `RockyCLI/Sources/RockyCLI/` stutter since the repo name already communicates it's the CLI.

RockyCore here is the CLI's core — SQLite, local models, repository layer, formatting. It is not shared with the platform.

### Planned Split

| Repo | Visibility | Contents |
|------|-----------|----------|
| `Rocky` (or renamed) | Public | RockyCore, RockyCLI, public OpenAPI spec, generated API client |
| TBD (`rocky-platform`, `rocky-server`, etc.) | Private | Hummingbird backend, its own core, private API specs, platform services |

Each repo has its own "core" with its own concerns. The platform core handles server-specific logic (routing, auth, Postgres, etc.). The CLI core handles local logic (SQLite, formatting, etc.). They do not share code — the shared contract is the OpenAPI spec only.

The public CLI repo is self-contained — anyone can clone, build, contribute, and install via Homebrew. The server repo is completely separate.

### Distribution

Rocky CLI currently distributes via Homebrew using prebuilt binaries hosted on GitHub releases. This works regardless of repo visibility since binaries are attached to public releases.

If the CLI repo ever went private, binaries would need to be hosted elsewhere (S3, CDN, etc.) to avoid requiring users to set up GitHub tokens. Keeping the CLI repo public avoids this entirely.

## Authentication

When a backend is configured, the CLI needs to authenticate API requests. Likely approach:

- `rocky config set api-key <key>` or a `rocky login` flow
- Credentials stored in local config
- No key configured = no backend = pure local mode

## Tech Choices

| Component | Technology | Reason |
|-----------|-----------|--------|
| Backend framework | [Hummingbird](https://hummingbird.codes) | Swift ecosystem, preference |
| API contract | OpenAPI | Enforces conformance between CLI and server |

## Open Questions

- Exact repo name for the platform
- Offline behavior in connected mode — fail writes? queue and sync later?
- Auth mechanism details (API key vs token-based login)
- Database for the backend (Postgres likely, but not decided)
- How the public OpenAPI spec is shared between repos (vendored, submodule, separate package?)
- Native app strategy and how it fits into the platform
