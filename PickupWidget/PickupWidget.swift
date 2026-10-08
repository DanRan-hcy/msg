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
                // 使用深色高对比背景，避免浅色锁屏卡片上出现白色文字不可读的问题。
                .activityBackgroundTint(Color(red: 0.08, green: 0.10, blue: 0.14))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        PickupIslandTile(size: 34)
                        Text("待取包裹")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.waitingCount)")
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        Text("件待取")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Divider()
                        .padding(.bottom, 2)
                    DynamicIslandPickupList(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("有待取包裹")
            } compactTrailing: {
                Text("\(context.state.waitingCount)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.blue)
                    .accessibilityLabel("未取 \(context.state.waitingCount) 件")
            } minimal: {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.16))
                    Image(systemName: "shippingbox.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .keylineTint(.blue)
        }
    }
}

private struct PickupIslandTile: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Color.blue.opacity(0.14))
            .overlay {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: size, height: size)
    }
}

private struct DynamicIslandPickupList: View {
    let state: PickupActivityAttributes.ContentState

    private var visibleStations: [PickupActivityAttributes.StationSummary] {
        Array(state.stations.prefix(5))
    }

    private var visibleCodeCount: Int {
        visibleStations.reduce(0) { $0 + $1.codes.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleStations, id: \.nameAndAddress) { station in
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(station.codes.joined(separator: "  ·  "))
                        .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            let hiddenCount = max(0, state.waitingCount - visibleCodeCount)
            if hiddenCount > 0 {
                HStack {
                    Text("更多包裹")
                    Spacer()
                    Text("另有 \(hiddenCount) 件")
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LockScreenPickupView: View {
    let state: PickupActivityAttributes.ContentState
    private let primaryText = Color.white
    private let secondaryText = Color.white.opacity(0.68)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("待取 \(state.waitingCount) 件", systemImage: "shippingbox.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.cyan)
                Spacer()
                Text(state.updatedAt, style: .relative)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryText)
            }
            StationCodesView(
                stations: state.stations,
                limit: 4,
                primaryText: primaryText,
                secondaryText: secondaryText
            )
        }
        .padding(.vertical, 8)
    }
}

private struct StationCodesView: View {
    let stations: [PickupActivityAttributes.StationSummary]
    let limit: Int
    let primaryText: Color
    let secondaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(stations.prefix(limit)), id: \.nameAndAddress) { station in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.cyan)
                        Text(station.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                        if !station.address.isEmpty {
                            Text(station.address)
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Text(station.codes.joined(separator: " · "))
                        .font(.system(.body, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                }
            }
            if stations.count > limit {
                Text("还有更多包裹待取")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension PickupActivityAttributes.StationSummary {
    var nameAndAddress: String { "\(name)|\(address)" }
}
