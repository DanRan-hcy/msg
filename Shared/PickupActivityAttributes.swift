import ActivityKit
import Foundation

struct PickupActivityAttributes: ActivityAttributes, Sendable {
    struct StationSummary: Codable, Hashable, Sendable {
        let name: String
        let address: String
        let codes: [String]
    }

    struct ContentState: Codable, Hashable, Sendable {
        let waitingCount: Int
        let stations: [StationSummary]
        let updatedAt: Date
    }

    let activityID: String
}
