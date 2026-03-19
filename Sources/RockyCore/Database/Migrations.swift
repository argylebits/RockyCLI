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

        migrator.registerMigration("v2", foreignKeyChecks: .deferred) { db in
            try db.execute(sql: """
                CREATE TABLE projects_new (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    parent_id   INTEGER REFERENCES projects(id),
                    name        TEXT    NOT NULL,
                    slug        TEXT    NOT NULL UNIQUE,
                    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                )
                """)

            let rows = try Row.fetchAll(db, sql: "SELECT * FROM projects")
            for row in rows {
                let id: Int = row["id"]
                let parentId: Int? = row["parent_id"]
                let name: String = row["name"]
                let createdAt: String = row["created_at"]
                let slug = name.slugified
                try db.execute(
                    sql: "INSERT INTO projects_new (id, parent_id, name, slug, created_at) VALUES (?, ?, ?, ?, ?)",
                    arguments: [id, parentId, name, slug, createdAt])
            }

            try db.execute(sql: "DROP TABLE projects")
            try db.execute(sql: "ALTER TABLE projects_new RENAME TO projects")
        }

        try migrator.migrate(db.dbQueue)
    }
}
