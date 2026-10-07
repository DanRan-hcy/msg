import Foundation
import SwiftData

enum PickupStatus: String, Codable, CaseIterable, Sendable {
    case waiting
    case completed
}

@Model
final class PickupItem {
    var id: UUID
    var rawMessage: String
    var stationName: String
    var stationAddress: String
    var courierName: String
    var code: String
    var receivedAt: Date
    var completedAt: Date?
    var statusRawValue: String
    var fingerprint: String
    var source: String = "shortcut"
    var confidence: Double = 1

    var status: PickupStatus {
        get { PickupStatus(rawValue: statusRawValue) ?? .waiting }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        rawMessage: String,
        stationName: String,
        stationAddress: String,
        courierName: String,
        code: String,
        receivedAt: Date = .now,
        fingerprint: String,
        source: String = "shortcut",
        confidence: Double = 1
    ) {
        id = UUID()
        self.rawMessage = rawMessage
        self.stationName = stationName
        self.stationAddress = stationAddress
        self.courierName = courierName
        self.code = code
        self.receivedAt = receivedAt
        statusRawValue = PickupStatus.waiting.rawValue
        self.fingerprint = fingerprint
        self.source = source
        self.confidence = confidence
    }
}
