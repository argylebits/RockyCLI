import Foundation

public protocol ProjectRepository: Sendable {
    func findOrCreate(name: String) async throws -> Project
    func getById(_ id: Int) async throws -> Project?
    func getByName(_ name: String) async throws -> Project?
    func list() async throws -> [Project]
}
