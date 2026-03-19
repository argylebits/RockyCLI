import Foundation

extension String {
    public var slugified: String {
        lowercased()
            .replacing(/[^a-z0-9]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
