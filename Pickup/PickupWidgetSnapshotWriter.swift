import Foundation
import SwiftData
import WidgetKit

@MainActor
enum PickupWidgetSnapshotWriter {
    static func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.statusRawValue == "waiting" },
            sortBy: [SortDescriptor(\PickupItem.receivedAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor) else { return }
        let grouped = Dictionary(grouping: items) {
            "\($0.stationName)|\($0.stationAddress)"
        }
        let stations = grouped.values.compactMap { group -> PickupWidgetSnapshot.Station? in
            guard let first = group.first else { return nil }
            return .init(
                name: first.stationName,
                address: first.stationAddress,
                codes: group.map(\.code).prefix(4).map { $0 }
            )
        }.sorted {
            let firstTime = grouped["\($0.name)|\($0.address)"]?.first?.receivedAt ?? .distantPast
            let secondTime = grouped["\($1.name)|\($1.address)"]?.first?.receivedAt ?? .distantPast
            return firstTime > secondTime
        }
        let snapshot = PickupWidgetSnapshot(waitingCount: items.count, stations: stations, updatedAt: .now)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: PickupStore.appGroupID)?.set(data, forKey: PickupWidgetSnapshot.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
