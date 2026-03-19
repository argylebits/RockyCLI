import Foundation

public protocol ProjectRepository: Sendable {
    func findOrCreate(name: String, slug: String) throws -> Project
    func getById(_ id: Int) throws -> Project?
    func getBySlug(_ slug: String) throws -> Project?
    func list() throws -> [Project]
}
