import Foundation
import RockyCore

struct SessionsWithProjects: Encodable {
    let sessions: [Session]
    let projects: [Project]
}
