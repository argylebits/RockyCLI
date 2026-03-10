import SQLiteNIO

enum Migrations {
    static func run(on db: Database) async throws {
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS migrations (
                version     INTEGER PRIMARY KEY,
                applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            )
            """)

        let rows = try await db.query(
            "SELECT COALESCE(MAX(version), 0) AS current_version FROM migrations"
        )
        let currentVersion = rows.first?.column("current_version")?.integer ?? 0

        if currentVersion < 1 {
            try await v1(on: db)
        }
    }

    private static func v1(on db: Database) async throws {
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                parent_id   INTEGER REFERENCES projects(id),
                name        TEXT    NOT NULL UNIQUE,
                created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            )
            """)

        try await db.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id  INTEGER NOT NULL REFERENCES projects(id),
                start_time  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                end_time    TEXT
            )
            """)

        try await db.execute(
            "INSERT INTO migrations (version) VALUES (?)",
            [.integer(1)]
        )
    }
}
