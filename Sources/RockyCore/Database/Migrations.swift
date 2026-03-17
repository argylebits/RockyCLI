import GRDB

enum Migrations {
    static func run(on db: Database) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS projects (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    parent_id   INTEGER REFERENCES projects(id),
                    name        TEXT    NOT NULL UNIQUE,
                    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                )
                """)

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sessions (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    project_id  INTEGER NOT NULL REFERENCES projects(id),
                    start_time  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                    end_time    TEXT
                )
                """)

            // Clean up the hand-rolled migrations table from the sqlite-nio era
            try db.execute(sql: "DROP TABLE IF EXISTS migrations")
        }

        try migrator.migrate(db.dbQueue)
    }
}
