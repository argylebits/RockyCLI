# Rocky — Database Schema

## Location

SQLite database stored at `~/.rocky/rocky.db`. Create directory if it doesn't exist.

## Tables

### projects

```sql
CREATE TABLE IF NOT EXISTS projects (
    id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    parent_id   INTEGER  REFERENCES projects(id),
    name        TEXT     NOT NULL,
    slug        TEXT     NOT NULL UNIQUE,
    created_at  DATETIME NOT NULL DEFAULT (datetime('now'))
);
```

**Notes:**
- `parent_id` is NULL for top-level projects
- Self-referencing FK enables subprojects (not used in v1 but schema supports it)
- `name` is the display name — stored exactly as provided by the user
- `slug` is the normalized lookup key — generated via `String.slugified` (lowercase, non-alphanumeric replaced with hyphens, collapsed, trimmed)
- All lookups and uniqueness enforcement use `slug` (exact match), not `name`
- No `COLLATE NOCASE` — case insensitivity is handled by slugification

### sessions

```sql
CREATE TABLE IF NOT EXISTS sessions (
    id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER  NOT NULL REFERENCES projects(id),
    start_time  DATETIME NOT NULL DEFAULT (datetime('now')),
    end_time    DATETIME
);
```

**Notes:**
- `end_time` being NULL means the timer is currently running (active session)
- A project can have multiple NULL end_times simultaneously (concurrent timers supported)
- All datetimes stored as UTC ISO8601 strings: `2026-03-06T14:30:00Z`
- Duration is always computed: `end_time - start_time` (or `now - start_time` if running)

## Derived data (never stored, always computed)

| Concept | How it's computed |
|---------|------------------|
| Is timer running | `end_time IS NULL` |
| Session duration | `end_time - start_time` or `now() - start_time` |
| Project "recency" | `MAX(end_time)` of most recent session for that project |
| Project color fade | Derived from recency at render time |

## Migrations

Run migrations on every startup. Use a simple version table:

```sql
CREATE TABLE IF NOT EXISTS migrations (
    version     INTEGER PRIMARY KEY,
    applied_at  DATETIME NOT NULL DEFAULT (datetime('now'))
);
```

Migration v1 creates `projects` and `sessions` tables.
Migration v2 adds `slug` column to `projects` (table rebuild, existing names slugified).
