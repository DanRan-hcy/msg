import ActivityKit
import Foundation
import SwiftData

@MainActor
enum PickupActivityManager {
    static let enabledKey = "pickup.liveActivity.enabled"

    enum RefreshResult: Equatable, Sendable {
        case noWaitingItems
        case disabled
        case systemDisabled
        case updated
        case started
        case failed(String)

        var message: String {
            switch self {
            case .noWaitingItems: return "当前没有待取包裹"
            case .disabled: return "已关闭实时动态"
            case .systemDisabled: return "系统设置未允许实时动态"
            case .updated: return "实时动态已更新"
            case .started: return "实时动态已开启"
            case let .failed(error): return "实时动态启动失败：\(error)"
            }
        }
    }

    static func refresh(context: ModelContext) async -> RefreshResult {
        let descriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.statusRawValue == "waiting" },
            sortBy: [SortDescriptor(\PickupItem.receivedAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor) else {
            return .failed("读取待取记录失败")
        }
        let existing = Activity<PickupActivityAttributes>.activities
        let isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        if items.isEmpty || !isEnabled {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return items.isEmpty ? .noWaitingItems : .disabled
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .systemDisabled }
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
            return .updated
        } else {
            let attributes = PickupActivityAttributes(activityID: UUID().uuidString)
            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60 * 8)),
                    pushType: nil
                )
                return .started
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }
}
