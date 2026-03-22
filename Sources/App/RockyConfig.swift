struct RockyConfig: Codable {
    var autoStop: Bool

    static let `default` = RockyConfig(autoStop: true)

    enum CodingKeys: String, CodingKey {
        case autoStop = "auto-stop"
    }

    init(autoStop: Bool = true) {
        self.autoStop = autoStop
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Config file stores bools as strings ("true"/"false")
        if let stringValue = try? container.decode(String.self, forKey: .autoStop) {
            self.autoStop = stringValue == "true"
        } else {
            self.autoStop = true
        }
    }
}
