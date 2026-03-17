import Foundation

public protocol ProjectRepository: Sendable {
    func findOrCreate(name: String) throws -> Project
    func getById(_ id: Int) throws -> Project?
    func getByName(_ name: String) throws -> Project?
    func list() throws -> [Project]
}
