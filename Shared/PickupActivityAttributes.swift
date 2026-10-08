import ActivityKit
import Foundation

struct PickupActivityAttributes: ActivityAttributes, Sendable {
    struct StationSummary: Codable, Hashable, Sendable {
        let name: String
        let address: String
        let codes: [String]
        // 使用可选字段兼容升级前已经创建的实时动态。
        var courierNames: [String]? = nil
    }

    struct ContentState: Codable, Hashable, Sendable {
        let waitingCount: Int
        let stations: [StationSummary]
        let updatedAt: Date
    }

    let activityID: String
}
