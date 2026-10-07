import Foundation

struct PickupWidgetSnapshot: Codable, Hashable, Sendable {
    static let appGroupID = "group.com.xxx.Pickup"
    static let storageKey = "pickup.widget.snapshot"

    struct Station: Codable, Hashable, Identifiable, Sendable {
        var id: String { "\(name)|\(address)" }
        let name: String
        let address: String
        let codes: [String]
    }

    let waitingCount: Int
    let stations: [Station]
    let updatedAt: Date

    static let empty = PickupWidgetSnapshot(waitingCount: 0, stations: [], updatedAt: .now)
}
