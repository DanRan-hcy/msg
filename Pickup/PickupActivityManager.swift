import ActivityKit
import Foundation
import SwiftData

@MainActor
enum PickupActivityManager {
    static func refresh(context: ModelContext) async {
        let descriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.statusRawValue == "waiting" },
            sortBy: [SortDescriptor(\PickupItem.receivedAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor) else { return }
        let existing = Activity<PickupActivityAttributes>.activities
        let isEnabled = UserDefaults.standard.object(forKey: "pickup.liveActivity.enabled") as? Bool ?? true
        if items.isEmpty || !isEnabled {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let groups = Dictionary(grouping: items) {
            "\($0.stationName)|\($0.stationAddress)"
        }
        let sortedGroups = groups.values.map { group in
            group.sorted { $0.receivedAt > $1.receivedAt }
        }.sorted {
            ($0.first?.receivedAt ?? .distantPast) > ($1.first?.receivedAt ?? .distantPast)
        }
        let stations = sortedGroups.prefix(8).compactMap { group -> PickupActivityAttributes.StationSummary? in
            guard let first = group.first else { return nil }
            return .init(
                name: first.stationName,
                address: first.stationAddress,
                codes: group.map(\.code).prefix(6).map { $0 }
            )
        }
        let state = PickupActivityAttributes.ContentState(
            waitingCount: items.count,
            stations: stations,
            updatedAt: .now
        )

        if let activity = existing.first {
            await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60 * 8)))
            for duplicate in existing.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            let attributes = PickupActivityAttributes(activityID: UUID().uuidString)
            _ = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60 * 8)),
                pushType: nil
            )
        }
    }
}
