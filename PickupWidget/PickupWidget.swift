import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PickupWidgetBundle: WidgetBundle {
    var body: some Widget {
        PickupLiveActivityWidget()
        PickupSummaryWidget()
    }
}

private struct PickupSummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: PickupWidgetSnapshot
}

private struct PickupSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickupSummaryEntry {
        PickupSummaryEntry(date: .now, snapshot: .init(
            waitingCount: 2,
            stations: [.init(name: "菜鸟驿站", address: "", codes: ["6-5218"])],
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (PickupSummaryEntry) -> Void) {
        completion(PickupSummaryEntry(date: .now, snapshot: readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PickupSummaryEntry>) -> Void) {
        let entry = PickupSummaryEntry(date: .now, snapshot: readSnapshot())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func readSnapshot() -> PickupWidgetSnapshot {
        guard let data = UserDefaults(suiteName: PickupWidgetSnapshot.appGroupID)?.data(forKey: PickupWidgetSnapshot.storageKey),
              let snapshot = try? JSONDecoder().decode(PickupWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

private struct PickupSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PickupSummaryWidget", provider: PickupSummaryProvider()) { entry in
            PickupSummaryView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("取件")
        .description("查看待取数量和常用取件码。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PickupSummaryView: View {
    let snapshot: PickupWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("待取 \(snapshot.waitingCount) 件", systemImage: "shippingbox.fill")
                .font(.headline)
                .lineLimit(1)
            if snapshot.waitingCount == 0 {
                Text("今天没有待取包裹")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.stations.prefix(2))) { station in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text(station.codes.joined(separator: " · "))
                            .font(.system(.body, design: .rounded).weight(.bold).monospacedDigit())
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

struct PickupLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupActivityAttributes.self) { context in
            LockScreenPickupView(state: context.state)
                .activityBackgroundTint(Color(red: 0.08, green: 0.10, blue: 0.14))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("待取 \(context.state.waitingCount) 件", systemImage: "shippingbox.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.leading, 8)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let hidden = PickupActivityDetails.hiddenCount(for: context.state)
                    Text(hidden > 0 ? "另有 \(hidden) 件 ›" : "打开取件 ›")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PickupActivityDetails(state: context.state)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.cyan)
                    .accessibilityLabel("有待取包裹")
            } compactTrailing: {
                Text("\(context.state.waitingCount)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.cyan)
                    .accessibilityLabel("未取 \(context.state.waitingCount) 件")
            } minimal: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.cyan)
            }
            .keylineTint(.cyan)
        }
    }
}

private struct LockScreenPickupView: View {
    let state: PickupActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("待取 \(state.waitingCount) 件", systemImage: "shippingbox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.cyan)
                Spacer(minLength: 8)
                let hidden = PickupActivityDetails.hiddenCount(for: state)
                Text(hidden > 0 ? "另有 \(hidden) 件 ›" : "打开取件 ›")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            PickupActivityDetails(state: state)
        }
        // 实时动态不会替内容补齐安全留白，需要显式避开卡片的圆角区域。
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 锁屏与展开灵动岛共用信息层级：驿站、快递公司、完整取件码。
private struct PickupActivityDetails: View {
    let state: PickupActivityAttributes.ContentState

    private static func codes(for station: PickupActivityAttributes.StationSummary, stationCount: Int) -> [String] {
        let hasLongCode = station.codes.prefix(stationCount > 1 ? 2 : 4).contains { $0.count > 12 }
        // 长码独占一行；普通码两列展示，剩余数量只按实际可见的码计算。
        let limit = hasLongCode ? (stationCount > 1 ? 1 : 2) : (stationCount > 1 ? 2 : 4)
        return Array(station.codes.prefix(limit))
    }

    static func hiddenCount(for state: PickupActivityAttributes.ContentState) -> Int {
        let visible = state.stations.prefix(2).reduce(0) {
            $0 + codes(for: $1, stationCount: state.stations.count).count
        }
        return max(0, state.waitingCount - visible)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(state.stations.prefix(2)), id: \.nameAndAddress) { station in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(station.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text((station.courierNames ?? []).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    let visibleCodes = Self.codes(for: station, stationCount: state.stations.count)
                    let columns = visibleCodes.contains { $0.count > 12 } || visibleCodes.count == 1 ? 1 : 2
                    let rows = stride(from: 0, to: visibleCodes.count, by: columns).map {
                        Array(visibleCodes[$0..<min($0 + columns, visibleCodes.count)])
                    }
                    VStack(spacing: 4) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 6) {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, code in
                                    Text(code)
                                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                                        .accessibilityLabel("取件码 \(code)")
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension PickupActivityAttributes.StationSummary {
    var nameAndAddress: String { "\(name)|\(address)" }
}
