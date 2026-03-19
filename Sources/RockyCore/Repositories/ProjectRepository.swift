import Foundation

public protocol ProjectRepository: Sendable {
    func create(name: String, slug: String) throws -> Project
    func get(id: Int) throws -> Project?
    func get(slug: String) throws -> Project?
    func list() throws -> [Project]
    func update(id: Int, name: String, slug: String) throws -> Project
}
