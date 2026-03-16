# Proposal: Migrate from sqlite-nio to GRDB

**Issue:** #75
**Status:** Approved — key decisions finalized 2026-03-16
**Date:** 2026-03-12

---

## Background

Rocky currently uses [sqlite-nio](https://github.com/vapor/sqlite-nio.git) (Vapor family) for all database access. This was chosen because the developer had prior experience with postgres-nio, and raw SQL was preferred over an ORM (see DECISIONS.md: "sqlite-nio over GRDB or Fluent").

This proposal re-evaluates that decision now that the project has matured and the actual usage patterns are clearer.

---

## Why reconsider?

### sqlite-nio is designed for servers, not CLIs

sqlite-nio is part of the Vapor ecosystem. It requires `NIOThreadPool`, `MultiThreadedEventLoopGroup`, and async connection management — machinery designed for high-concurrency server workloads. Rocky is a single-user CLI tool that runs one query at a time.

Current boilerplate in `Database.swift`:
- 1 NIOThreadPool (1 thread)
- 1 MultiThreadedEventLoopGroup (1 thread)
- Manual graceful shutdown of both on close
- `nonisolated(unsafe)` annotation to work around Sendability constraints on row collection

None of this complexity serves the application.

### GRDB supports raw SQL equally well

The original concern was ORM vs raw SQL. GRDB is **not an ORM** — it is a SQLite toolkit that provides raw SQL execution as a first-class API:

```swift
// Raw SQL works exactly as you'd expect
let rows = try db.execute(sql: "SELECT * FROM sessions WHERE end_time IS NULL")
let sessions = try Session.fetchAll(db, sql: "SELECT * FROM sessions WHERE project_id = ?", arguments: [projectId])
```

Every query Rocky currently runs can be executed identically through GRDB's raw SQL interface. The query interface and record protocols are opt-in conveniences, not requirements.

### Dependency posture

sqlite-nio pulls in the full SwiftNIO stack (`swift-nio`, `swift-nio-posix`, `swift-log`). GRDB has zero external dependencies — it vendors its own SQLite build or links the system SQLite.

---

## Current database layer inventory

### Files that would change

| File | Lines | Role | What changes |
|------|-------|------|-------------|
| `Package.swift` | 47 | Dependencies | Swap sqlite-nio → GRDB |
| `Database.swift` | 74 | Connection management | Replace NIO machinery with GRDB DatabaseQueue |
| `Migrations.swift` | 46 | Schema versioning | Replace hand-rolled system with GRDB DatabaseMigrator |
| `SQLiteRow+Codable.swift` | 25 | Row deserialization | **Delete entirely** — GRDB's FetchableRecord replaces this |
| `SQLiteProjectRepository.swift` | 51 | Project queries | Update to use GRDB database access |
| `SQLiteSessionRepository.swift` | 143 | Session queries | Update to use GRDB database access |
| `SQLiteIntegrationTests.swift` | 131 | Integration tests | Update TestDatabase and query syntax |

### Files that would NOT change

| File | Role | Why unchanged |
|------|------|--------------|
| `ProjectRepository.swift` | Protocol | No database types in the interface |
| `SessionRepository.swift` | Protocol | No database types in the interface |
| `Project.swift` | Model | Would gain protocol conformances but struct stays the same |
| `Session.swift` | Model | Would gain protocol conformances but struct stays the same |
| `MockProjectRepository.swift` | Mock | No database dependency |
| `MockSessionRepository.swift` | Mock | No database dependency |
| `DashboardService.swift` | Service | Calls repository protocols, not database directly |
| `SessionService.swift` | Service | Calls repository protocols, not database directly |
| `ProjectService.swift` | Service | Calls repository protocols, not database directly |
| All `App/` files | CLI layer | Never touches the database |
| All tests using mocks | Tests | Mock-based tests are unchanged |

The protocol-based architecture means the blast radius is contained entirely within `Sources/RockyCore/Database/` and `Sources/RockyCore/Repositories/SQLite/`.

---

## Query-by-query migration assessment

### Migrations.swift (4 statements → replaced by DatabaseMigrator)

The hand-rolled migration system (create migrations table, check max version, run versioned functions) is replaced entirely by GRDB's built-in `DatabaseMigrator`:

```swift
// Before (hand-rolled, 46 lines)
try await db.execute("CREATE TABLE IF NOT EXISTS migrations (...)")
let rows = try await db.query("SELECT COALESCE(MAX(version), 0) ...")
// ... version checking logic ...
try await db.execute("CREATE TABLE IF NOT EXISTS projects (...)")
try await db.execute("CREATE TABLE IF NOT EXISTS sessions (...)")
try await db.execute("INSERT INTO migrations (version) VALUES (?)", ...)

// After (GRDB built-in)
var migrator = DatabaseMigrator()
migrator.registerMigration("v1") { db in
    try db.create(table: "projects") { t in
        t.autoIncrementedPrimaryKey("id")
        t.belongsTo("parent", inTable: "projects").references("projects", onDelete: .setNull)
        t.column("name", .text).notNull().unique()
        t.column("created_at", .datetime).notNull().defaults(sql: "datetime('now')")
    }
    try db.create(table: "sessions") { t in
        t.autoIncrementedPrimaryKey("id")
        t.belongsTo("project", inTable: "projects").notNull()
        t.column("start_time", .datetime).notNull().defaults(sql: "datetime('now')")
        t.column("end_time", .datetime)
    }
}
try migrator.migrate(dbQueue)
```

**Assessment:** Clear improvement. Eliminates boilerplate, gains automatic migration tracking, and the schema definition is more readable. GRDB's migrator also handles the migrations table internally.

**Schema note:** The resulting tables must produce the exact same schema as defined in SCHEMA.md. The column names, types, constraints, and defaults must match. This needs verification during implementation.

---

### SQLiteProjectRepository (4 queries)

#### 1. findOrCreate — INSERT + lastAutoincrementID + SELECT

```swift
// Before: 3 separate calls
try await db.execute("INSERT INTO projects (name) VALUES (?)", [.text(name)])
let id = try await db.lastAutoincrementID()
let rows = try await db.query("SELECT * FROM projects WHERE id = ?", [.integer(id)])
return try rows[0].decode(Project.self)

// After: raw SQL through GRDB, Codable row mapping
try db.execute(sql: "INSERT INTO projects (name) VALUES (?)", arguments: [name])
let id = db.lastInsertedRowID
return try Project.fetchOne(db, sql: "SELECT * FROM projects WHERE id = ?", arguments: [id])!
```

**Assessment: Raw SQL.** Same queries, GRDB handles row → struct mapping via FetchableRecord. Eliminates custom `SQLiteData` binds and `SQLiteRow+Codable` decoding.

#### 2. getById — `SELECT * FROM projects WHERE id = ?`

```swift
// Before
let rows = try await db.query("SELECT * FROM projects WHERE id = ?", [.integer(id)])
return try rows.first?.decode(Project.self)

// After: raw SQL through GRDB
return try Project.fetchOne(db, sql: "SELECT * FROM projects WHERE id = ?", arguments: [id])
```

**Assessment: Raw SQL.** Same query, GRDB handles row decoding.

#### 3. getByName — `SELECT * WHERE name = ? COLLATE NOCASE`

```swift
// Before
let rows = try await db.query(
    "SELECT * FROM projects WHERE name = ? COLLATE NOCASE", [.text(name)])

// After: raw SQL through GRDB
return try Project.fetchOne(db, sql:
    "SELECT * FROM projects WHERE name = ? COLLATE NOCASE", arguments: [name])
```

**Assessment: Raw SQL.** Same query, GRDB handles row decoding.

#### 4. list — `SELECT * FROM projects ORDER BY created_at ASC`

```swift
// Before
let rows = try await db.query("SELECT * FROM projects ORDER BY created_at ASC")
return try rows.map { try $0.decode(Project.self) }

// After: raw SQL through GRDB
return try Project.fetchAll(db, sql: "SELECT * FROM projects ORDER BY created_at ASC")
```

**Assessment: Raw SQL.** Same query, GRDB handles row decoding.

---

### SQLiteSessionRepository (16 queries across 10 methods)

#### 1. start — `INSERT INTO sessions (project_id) VALUES (?)`

```swift
// Before
try await db.execute("INSERT INTO sessions (project_id) VALUES (?)", [.integer(projectId)])

// After: raw SQL through GRDB, Date() for start_time
try db.execute(
    sql: "INSERT INTO sessions (project_id, start_time) VALUES (?, ?)",
    arguments: [projectId, Date()])
```

**Assessment: Raw SQL.** Uses `Date()` instead of database DEFAULT `datetime('now')`. Both read the same system clock — decided 2026-03-16.

#### 2. hasRunningSession — `SELECT id WHERE ... AND end_time IS NULL LIMIT 1`

```swift
// Before
let rows = try await db.query(
    "SELECT id FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
    [.integer(projectId)])
return !rows.isEmpty

// After: raw SQL through GRDB
let rows = try Row.fetchAll(db, sql:
    "SELECT id FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
    arguments: [projectId])
return !rows.isEmpty
```

**Assessment: Raw SQL.** Same query, same logic.

#### 3. stop — SELECT + UPDATE with strftime + SELECT

```swift
// Before: 3 steps
let rows = try await db.query(
    "SELECT * FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1", ...)
try await db.execute(
    "UPDATE sessions SET end_time = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?", ...)
let updated = try await db.query("SELECT * FROM sessions WHERE id = ?", ...)

// After: raw SQL through GRDB, Date() for end_time
guard let session = try Session.fetchOne(db, sql:
    "SELECT * FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
    arguments: [projectId]) else {
    throw RockyCoreError.noRunningTimers
}
try db.execute(
    sql: "UPDATE sessions SET end_time = ? WHERE id = ?",
    arguments: [Date(), session.id])
return try Session.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = ?", arguments: [session.id])!
```

**Decision (2026-03-16):** Use `Date()` for all timestamps. Replaces `strftime('now')` — both read the same system clock. GRDB configured with ISO8601 encoding to match existing data format.

#### 4. stopAll — Loop of stop operations

Same pattern as `stop()` repeated in a loop. Same decision: use `Date()` for timestamps, migrate fully to GRDB.

#### 5. getRunning — `SELECT * WHERE end_time IS NULL ORDER BY start_time ASC`

```swift
// Before
let rows = try await db.query(
    "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC")

// After: raw SQL through GRDB
return try Session.fetchAll(db, sql:
    "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC")
```

**Assessment: Raw SQL.** Same query, GRDB handles row decoding.

#### 6. getRunningWithProjects — JOIN with column aliasing

```swift
// Before
let rows = try await db.query("""
    SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
           p.name AS p_name, p.created_at AS p_created_at
    FROM sessions s
    JOIN projects p ON s.project_id = p.id
    WHERE s.end_time IS NULL
    ORDER BY s.start_time ASC
    """)
return try rows.map { row in
    let session = try row.decode(Session.self)
    let project = try row.decode(Project.self, prefix: "p_")
    return (session, project)
}

// After: raw SQL through GRDB, Row subscript for column aliasing
let rows = try Row.fetchAll(db, sql: """
    SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
           p.name AS p_name, p.created_at AS p_created_at
    FROM sessions s
    JOIN projects p ON s.project_id = p.id
    WHERE s.end_time IS NULL
    ORDER BY s.start_time ASC
    """)
return rows.map { row in
    let session = Session(row: row)
    let project = Project(id: row["p_id"], parentId: row["p_parent_id"],
                          name: row["p_name"], createdAt: row["p_created_at"])
    return (session, project)
}
```

**Assessment: Raw SQL.** Same query. GRDB's `Row` subscript replaces the custom `SQLiteRow+Codable` prefix decoding.

#### 7. insert — `INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)`

```swift
// Before
var binds: [SQLiteData] = [.integer(projectId), startTime.sqliteBind]
binds.append(endTime?.sqliteBind ?? .null)
try await db.execute("INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)", binds)

// After: raw SQL through GRDB
try db.execute(
    sql: "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
    arguments: [projectId, startTime, endTime])
```

**Assessment: Raw SQL.** Same query. GRDB handles Date encoding via configured ISO8601 format, eliminating manual `SQLiteData` binds.

#### 8. getById — `SELECT * FROM sessions WHERE id = ?`

```swift
// After: raw SQL through GRDB
return try Session.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = ?", arguments: [id])
```

**Assessment: Raw SQL.** Same query, GRDB handles row decoding.

#### 9. update — `UPDATE sessions SET start_time = ?, end_time = ? WHERE id = ?`

```swift
// Before
var binds: [SQLiteData] = [startTime.sqliteBind]
binds.append(endTime?.sqliteBind ?? .null)
binds.append(.integer(id))
try await db.execute("UPDATE sessions SET start_time = ?, end_time = ? WHERE id = ?", binds)
let rows = try await db.query("SELECT * FROM sessions WHERE id = ?", [.integer(id)])

// After: raw SQL through GRDB (keeps Session `let` immutability)
try db.execute(
    sql: "UPDATE sessions SET start_time = ?, end_time = ? WHERE id = ?",
    arguments: [startTime, endTime, id])
return try Session.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = ?", arguments: [id])!
```

**Assessment: Raw SQL.** Preserves `let` properties on Session (decided 2026-03-16). Same query, GRDB handles Date encoding and row decoding.

#### 10. getSessions — JOIN + date range + optional filter + dynamic SQL

```swift
// Before
var sql = """
    SELECT s.*, p.id AS p_id, ...
    FROM sessions s JOIN projects p ON s.project_id = p.id
    WHERE (s.start_time < ? AND (s.end_time > ? OR s.end_time IS NULL))
    """
var binds: [SQLiteData] = [to.sqliteBind, from.sqliteBind]
if let projectId {
    sql += " AND s.project_id = ?"
    binds.append(.integer(projectId))
}
sql += " ORDER BY s.start_time ASC"
```

**Assessment: Keep raw SQL.** Dynamic WHERE clause construction, JOIN with column aliasing, and the overlap predicate (`start < to AND (end > from OR end IS NULL)`) — this is the most complex query in the codebase. It reads clearly as SQL and would be harder to follow in the query interface.

---

## Summary of migration approach per query

| # | Location | Query | Approach |
|---|----------|-------|----------|
| 1-4 | Migrations.swift | Schema DDL + version tracking | **Replace** with GRDB DatabaseMigrator |
| 5 | ProjectRepo.findOrCreate | INSERT + fetch back | **Raw SQL** — `INSERT`, use GRDB's `lastInsertedRowID` + `fetchOne` |
| 6 | ProjectRepo.getById | SELECT by PK | **Raw SQL** — `SELECT * FROM projects WHERE id = ?` with `fetchOne` |
| 7 | ProjectRepo.getByName | SELECT COLLATE NOCASE | **Raw SQL** — `SELECT * ... COLLATE NOCASE` with `fetchOne` |
| 8 | ProjectRepo.list | SELECT ORDER BY | **Raw SQL** — `SELECT * FROM projects ORDER BY created_at ASC` with `fetchAll` |
| 9 | SessionRepo.start | INSERT | **Raw SQL** — `INSERT INTO sessions ...` |
| 10 | SessionRepo.hasRunningSession | SELECT EXISTS | **Raw SQL** — `SELECT id ... LIMIT 1` |
| 11-12 | SessionRepo.stop | UPDATE + fetch back | **Raw SQL** — `UPDATE` with `Date()` for end_time, `fetchOne` for return |
| 13-14 | SessionRepo.stopAll | Loop of stop | Same as stop |
| 15 | SessionRepo.getRunning | SELECT filter + order | **Raw SQL** — `SELECT * ... WHERE end_time IS NULL ORDER BY start_time ASC` |
| 16-17 | SessionRepo.getRunningWithProjects | JOIN + alias decode | **Raw SQL** — JOIN with column aliasing |
| 18 | SessionRepo.insert | INSERT with values | **Raw SQL** — `INSERT INTO sessions (...) VALUES (?, ?, ?)` |
| 19 | SessionRepo.getById | SELECT by PK | **Raw SQL** — `SELECT * FROM sessions WHERE id = ?` with `fetchOne` |
| 20 | SessionRepo.update | UPDATE + fetch back | **Raw SQL** — `UPDATE sessions SET ... WHERE id = ?` |
| 21-22 | SessionRepo.getSessions | JOIN + dynamic WHERE | **Raw SQL** — JOIN + dynamic WHERE + date range |

**Totals:** All queries use raw SQL through GRDB. GRDB provides the infrastructure (DatabaseQueue, Codable row mapping via FetchableRecord, DatabaseMigrator) while SQL stays inline and explicit.

---

## Model changes required

Both models need GRDB protocol conformances. The struct shapes stay the same.

### Project

```swift
// Current
public struct Project: Codable, Sendable { ... }

// After: add GRDB conformances
extension Project: FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "projects"
}
```

`FetchableRecord` can be derived automatically from `Codable` — GRDB uses the same CodingKeys, so `parent_id` ↔ `parentId` mapping works as-is.

### Session

```swift
// Current: all properties are `let`
public struct Session: Codable, Sendable {
    public let id: Int
    public let projectId: Int
    public let startTime: Date
    public let endTime: Date?
}

// After: stays `let` — no change to the struct
public struct Session: Codable, Sendable {
    public let id: Int
    public let projectId: Int
    public let startTime: Date
    public let endTime: Date?
}
```

**Decision (2026-03-16):** Keep `let` properties. The `update()` method in `SQLiteSessionRepository` uses raw SQL instead of GRDB's record update to preserve immutability.

---

## Database.swift rewrite

The entire NIO stack is replaced by a single `DatabaseQueue`:

```swift
// Before: 74 lines
import SQLiteNIO
import NIOPosix
import Logging

public final class Database: Sendable {
    private let connection: SQLiteConnection
    private let threadPool: NIOThreadPool
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    // ... open(), close(), query(), execute(), lastAutoincrementID()
}

// After: ~30 lines
import GRDB

public final class Database: Sendable {
    let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func open() throws -> Database { ... }
    public static func open(at path: String) throws -> Database { ... }
    // No close() needed — DatabaseQueue handles cleanup
    // No threadPool, no eventLoopGroup, no manual shutdown
}
```

**Key changes:**
- `async throws` → `throws` on open (no NIO event loop needed)
- `close()` may become unnecessary (DatabaseQueue manages its own lifecycle)
- `query()` and `execute()` wrappers may be removed — repositories call `dbQueue.read { }` and `dbQueue.write { }` directly
- `lastAutoincrementID()` no longer needed — GRDB returns IDs from insert operations

---

## Async/await implications

sqlite-nio is inherently async (NIO event loop). GRDB is synchronous by default.

**Decision (2026-03-16):** Drop `async` from the entire stack. GRDB is synchronous, and nothing in Rocky's stack needs async. Keeping `async` on purely synchronous code is misleading — it signals "this does I/O on another thread" when it doesn't.

**What changes:**
- Repository protocols: `async throws` → `throws`
- Service methods: `async throws` → `throws`
- CLI commands: `AsyncParsableCommand` → `ParsableCommand`, `run() async throws` → `run() throws`
- `AppContext.build()`: `async throws` → `throws`
- `Database.open()`: `async throws` → `throws`
- `close()`: removed entirely — `DatabaseQueue` manages its own lifecycle
- All `await` keywords removed from call sites

**Why:** `async/await` was only present because sqlite-nio required NIO infrastructure (event loops, thread pools). With GRDB, it's unnecessary complexity. If async is needed in the future (e.g., backend sync), it can be added back to the specific methods that need it.

**Additional changes required:**
- Repository protocols move to the "files that change" list (signature change)
- Service layer moves to the "files that change" list (signature change)
- App commands move to the "files that change" list (`AsyncParsableCommand` → `ParsableCommand`)
- Mock repositories move to the "files that change" list (protocol conformance update)

---

## Files deleted

| File | Reason |
|------|--------|
| `SQLiteRow+Codable.swift` | Replaced by GRDB's FetchableRecord (Codable-based row decoding is built in) |

The `Date.sqliteBind` extension also goes away — GRDB handles Date encoding/decoding natively via `DatabaseValueConvertible`.

---

## What does NOT change

- **Database schema** — identical tables, columns, types, constraints, defaults
- **Database file location** — `~/.rocky/rocky.db`
- **All observable behavior** — same queries, same results, same error cases
- **Output formatting** — all CLI output unchanged
- **Business logic** — services still delegate to repository protocols, no logic changes

## What changes beyond the database layer

Due to the decision to drop `async/await`, the following files change (signature only — `async throws` → `throws`):

- **Repository protocols** — `ProjectRepository`, `SessionRepository` remove `async`
- **Service layer** — all service methods remove `async`
- **App commands** — `AsyncParsableCommand` → `ParsableCommand`, `run() async throws` → `run() throws`
- **AppContext** — `build()` and `close()` remove `async`; `close()` may be removed entirely
- **Mock repositories** — protocol conformance update (remove `async`)
- **All tests** — remove `await` from call sites

---

## Risks and concerns

### Existing database compatibility

Users upgrading from sqlite-nio to GRDB will have an existing `~/.rocky/rocky.db`. GRDB must be able to open and operate on it without migration issues. Since GRDB can open any SQLite database, this should work — but it needs testing with a real database file created by the current version.

The hand-rolled `migrations` table will still exist in the database. GRDB's `DatabaseMigrator` uses its own internal tracking (a `grdb_migrations` table). We need to ensure GRDB either ignores the old table or we handle the transition (e.g., check the old table's state on first GRDB run, then let GRDB's migrator take over for future versions).

### Date storage format

Current code stores dates as `2026-03-06T14:30:00Z` (ISO8601 with Z suffix). GRDB's default date encoding uses `YYYY-MM-DD HH:MM:SS.SSS` format. We must configure GRDB to match the existing format or existing data will fail to decode.

This is solvable — GRDB supports custom date formatting via `DatabaseDateEncodingStrategy` and `DatabaseDateDecodingStrategy` — but it must be explicitly configured and tested against existing data.

### strftime('now') vs Date()

**Decided (2026-03-16):** Use `Date()` everywhere. Both `strftime('now')` and `Date()` read the same system clock on a local machine. `Date()` is consistent with GRDB's record operations and simpler. Client timestamps are provisional — a future hosted backend will be the authoritative clock.

### Test infrastructure

`TestDatabase` actor currently exposes `db.execute()` and `db.query()` for direct SQL in tests. After migration, tests need to use GRDB's `DatabaseQueue` API. The `:memory:` database pattern is supported by GRDB, so the test approach stays the same — just the syntax changes.

---

## Impact on DECISIONS.md

This migration would require updating the following entry in DECISIONS.md:

> **sqlite-nio over GRDB or Fluent**
> The developer has prior experience with postgres-nio (same Vapor family). Raw SQL is preferred over ORM. sqlite-nio allows raw SQL with async/await patterns consistent with postgres-nio experience.

Proposed revision (if migration is approved):

> **GRDB over sqlite-nio or Fluent**
> GRDB provides connection management (DatabaseQueue), Codable row mapping (FetchableRecord), and migration tracking (DatabaseMigrator) — without ORM overhead. Chosen over sqlite-nio because NIO's async server infrastructure adds unnecessary complexity for a CLI tool. All queries use raw SQL through GRDB for readability and debuggability. All timestamps use Swift `Date()` with ISO8601 encoding.

---

## Impact on CLAUDE.md

The RockyCore target rule currently states:

> **Raw SQL only** — use sqlite-nio directly, no ORM, no query builders

This would need revision to reflect the mixed approach:

> **Raw SQL through GRDB** — all queries use raw SQL via GRDB (`db.execute(sql:)`, `Model.fetchOne(db, sql:)`, `Model.fetchAll(db, sql:)`). Do not use GRDB's query interface (`.filter()`, `.order()`). GRDB provides connection management, Codable row mapping, and migration tracking — not query generation. All timestamps use Swift `Date()` with ISO8601 encoding.

---

## Implementation order (if approved)

1. Update `Package.swift` — swap dependency
2. Rewrite `Database.swift` — DatabaseQueue, remove NIO
3. Rewrite `Migrations.swift` — DatabaseMigrator, handle existing migration table transition
4. Add GRDB conformances to `Project` and `Session` models
5. Rewrite `SQLiteProjectRepository.swift`
6. Rewrite `SQLiteSessionRepository.swift`
7. Delete `SQLiteRow+Codable.swift`
8. Update `SQLiteIntegrationTests.swift`
9. Verify all existing tests pass
10. Test against an existing database file from current version
11. Update `DECISIONS.md` and `CLAUDE.md`

All in a single PR against a feature branch.
