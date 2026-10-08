import ActivityKit
import SwiftData
import SwiftUI
import UIKit

private struct PickupStationGroup: Identifiable {
    let id: String
    let name: String
    let address: String
    let items: [PickupItem]
}

struct PickupHomeView: View {
    let items: [PickupItem]
    @Binding var searchText: String
    let onAdd: () -> Void
    let onComplete: (PickupItem) -> Void
    let onDelete: (PickupItem) -> Void
    let onCompleteAll: ([PickupItem]) -> Void
    @State private var showingCompleteAllConfirmation = false
    @State private var floatingButtonOffset = CGSize.zero
    @GestureState private var floatingButtonDrag = CGSize.zero

    private var groups: [PickupStationGroup] {
        let values = Dictionary(grouping: items) { "\($0.stationName)|\($0.stationAddress)" }
        return values.map { key, items in
            let sorted = items.sorted { $0.receivedAt > $1.receivedAt }
            return PickupStationGroup(
                id: key,
                name: sorted.first?.stationName ?? "其他驿站",
                address: sorted.first?.stationAddress ?? "",
                items: sorted
            )
        }.sorted {
            ($0.items.first?.receivedAt ?? .distantPast) > ($1.items.first?.receivedAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if items.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "今天没有待取包裹" : "没有匹配的取件信息",
                            systemImage: "shippingbox",
                            description: Text(searchText.isEmpty
                                              ? "收到取件短信后，可通过快捷指令添加。也可以点右上角手动添加。"
                                              : "试试搜索取件码、驿站、地址或快递公司。")
                        )
                        .padding(.top, 54)
                    } else {
                        HomeSummaryView(count: items.count, stationCount: groups.count)

                        ForEach(groups) { group in
                            VStack(spacing: 0) {
                                NavigationLink {
                                    PickupStationDetailView(
                                        stationName: group.name,
                                        stationAddress: group.address,
                                        onComplete: onComplete,
                                        onDelete: onDelete,
                                        onCompleteAll: onCompleteAll
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: stationSymbol(for: group.name))
                                            .font(.title3.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .frame(width: 38, height: 38)
                                            .background(.quaternary, in: Circle())
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(group.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(group.items.count) 个包裹")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 10)
                                }
                                .buttonStyle(.plain)

                                ForEach(group.items) { item in
                                    PickupCodeRow(item: item, onComplete: { onComplete(item) }, onDelete: { onDelete(item) })
                                        .padding(.horizontal, 14)
                                }

                                Color.clear.frame(height: 12)
                            }
                            .background(
                                Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                if !items.isEmpty {
                    Button {
                        showingCompleteAllConfirmation = true
                    } label: {
                        Image(systemName: "checklist")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 54, height: 54)
                            .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                            }
                            .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("全部标记为已取")
                    .offset(
                        x: floatingButtonOffset.width + floatingButtonDrag.width,
                        y: floatingButtonOffset.height + floatingButtonDrag.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .updating($floatingButtonDrag) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                floatingButtonOffset.width += value.translation.width
                                floatingButtonOffset.height += value.translation.height
                            }
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("取件")
            .searchable(text: $searchText, prompt: "搜索取件码、驿站或地址")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .systemBackground).opacity(0.72), in: Circle())
                            .overlay { Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.8) }
                    }
                    .accessibilityLabel("手动添加")
                }
            }
            .pickupPrompt(
                isPresented: $showingCompleteAllConfirmation,
                title: "全部标记为已取？",
                message: "共 \(items.count) 个待取包裹会移入历史记录。",
                confirmTitle: "全部标记为已取"
            ) {
                onCompleteAll(items)
            }
        }
    }
}

private struct HomeSummaryView: View {
    let count: Int
    let stationCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                Image(systemName: "shippingbox.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("待取包裹")
                    .font(.title3.weight(.semibold))
                Text("\(count) 个 · 来自 \(stationCount) 个驿站")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }
}

struct PickupStationDetailView: View {
    @State private var showingCompleteAllConfirmation = false
    @Query private var items: [PickupItem]
    let stationName: String
    let stationAddress: String
    let onComplete: (PickupItem) -> Void
    let onDelete: (PickupItem) -> Void
    let onCompleteAll: ([PickupItem]) -> Void

    init(
        stationName: String,
        stationAddress: String,
        onComplete: @escaping (PickupItem) -> Void,
        onDelete: @escaping (PickupItem) -> Void,
        onCompleteAll: @escaping ([PickupItem]) -> Void
    ) {
        self.stationName = stationName
        self.stationAddress = stationAddress
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onCompleteAll = onCompleteAll
        let name = stationName
        let address = stationAddress
        _items = Query(
            filter: #Predicate<PickupItem> {
                $0.statusRawValue == "waiting" && $0.stationName == name && $0.stationAddress == address
            },
            sort: \PickupItem.receivedAt,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(items.count) 个包裹")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if items.isEmpty {
                    ContentUnavailableView("这个驿站没有待取包裹", systemImage: "checkmark.circle")
                        .padding(.top, 40)
                } else {
                    ForEach(items) { item in
                        PickupDetailCard(item: item, onComplete: { onComplete(item) }, onDelete: { onDelete(item) })
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(stationName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                Button {
                    showingCompleteAllConfirmation = true
                } label: {
                    Label("全部标记为已取", systemImage: "checklist")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
            }
        }
        .pickupPrompt(
            isPresented: $showingCompleteAllConfirmation,
            title: "这个驿站的包裹全部已取？",
            message: "共 \(items.count) 个待取包裹会移入历史记录。",
            confirmTitle: "全部标记为已取"
        ) {
            onCompleteAll(items)
        }
    }
}

struct PickupHistoryView: View {
    let items: [PickupItem]
    @Binding var searchText: String
    let onDelete: (PickupItem) -> Void

    private var dayGroups: [(day: Date, items: [PickupItem])] {
        Dictionary(grouping: items) { item in
            Calendar.current.startOfDay(for: item.completedAt ?? item.receivedAt)
        }.map { day, values in
            (day, values.sorted { ($0.completedAt ?? $0.receivedAt) > ($1.completedAt ?? $1.receivedAt) })
        }.sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "暂无取件记录" : "没有匹配的历史记录",
                        systemImage: "clock",
                        description: Text(searchText.isEmpty ? "标记为已取的包裹会保留在这里。" : "试试搜索取件码、驿站或地址。")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(dayGroups, id: \.day) { group in
                        Section(dayTitle(group.day)) {
                            ForEach(group.items) { item in
                                PickupHistoryRow(item: item, onDelete: { onDelete(item) })
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("历史")
            .searchable(text: $searchText, prompt: "搜索历史取件")
        }
    }
}

struct PickupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("pickup.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("pickup.liveActivity.enabled") private var liveActivitiesEnabled = true
    @State private var showingClearConfirmation = false
    @State private var showingSampleClearConfirmation = false
    @State private var showingNotificationDenied = false
    @State private var showingClearError = false
    @State private var showingSampleError = false
    @State private var activityPermissionEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var activityStatus = "检查中…"
    @State private var showingActivityError = false
    let waitingCount: Int
    let completedCount: Int
    let sampleCount: Int

    var body: some View {
        NavigationStack {
            List {
                Section("快捷指令") {
                    LabeledContent("动作名称", value: "添加取件短信")
                    Text("按步骤创建自动化，让收到的短信自动交给取件 App 整理。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        PickupShortcutGuideView()
                    } label: {
                        Label("查看添加步骤", systemImage: "list.number")
                    }
                    if let shortcutsURL = URL(string: "shortcuts://") {
                        Link(destination: shortcutsURL) {
                            Label("打开快捷指令", systemImage: "arrow.up.forward.app")
                        }
                    }
                }

                Section("实时动态") {
                    Toggle("在灵动岛和锁定画面显示", isOn: $liveActivitiesEnabled)
                        .onChange(of: liveActivitiesEnabled) { _, _ in
                            refreshActivity()
                        }
                    LabeledContent("系统状态", value: activityStatus)
                    if !activityPermissionEnabled {
                        Button("打开系统设置") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                    Text("将所有待取包裹汇总显示。系统可能会限制实时动态的展示时长。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("通知") {
                    Toggle("收到新取件码时通知", isOn: Binding(
                        get: { notificationsEnabled },
                        set: { updateNotificationPreference($0) }
                    ))
                    Text("默认关闭。开启后，快捷指令或手动添加新记录时会发送一条本地通知。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("解析规则") {
                    Text("支持取件码、取货码、自提码、取件密码、柜门密码、开箱码和验证码等写法。验证码只有与快递、包裹或驿站上下文同时出现时才会识别。")
                        .font(.footnote)
                    Text("会尝试识别驿站、地址和快递公司；无法确认驿站时归入“其他驿站”，不会补造地址。订单号、手机号和较长纯数字会被排除。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据管理") {
                    LabeledContent("待取包裹", value: "\(waitingCount) 件")
                    LabeledContent("历史记录", value: "\(completedCount) 件")
                    LabeledContent("示例数据", value: "\(sampleCount) 条")
                    if sampleCount == 0 {
                        Button("添加示例数据", action: addSamples)
                    } else {
                        Button("清除示例数据", role: .destructive) {
                            showingSampleClearConfirmation = true
                        }
                    }
                    Text("示例数据用来体验待取、复制和历史页面，记录旁会标注“示例”；可单独清除。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("清除全部历史记录", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(completedCount == 0)
                    Text("待取记录不会自动删除。清除历史后无法恢复。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("隐私") {
                    Label("取件信息只保存在此 iPhone。", systemImage: "lock.shield")
                    Text("App 不上传短信内容、不连接服务器、不使用 AI，也不收集使用数据。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .pickupPrompt(
                isPresented: $showingClearConfirmation,
                title: "清除全部历史记录？",
                message: "此操作无法撤销。待取包裹不会受影响。",
                confirmTitle: "清除历史记录",
                isDestructive: true,
                action: clearHistory
            )
            .pickupPrompt(
                isPresented: $showingSampleClearConfirmation,
                title: "清除示例数据？",
                message: "只会删除标记为“示例”的记录，不影响你的取件信息。",
                confirmTitle: "清除示例数据",
                isDestructive: true,
                action: clearSamples
            )
            .pickupPrompt(
                isPresented: $showingNotificationDenied,
                title: "通知权限未开启",
                message: "请在系统设置中允许“取件”发送通知，然后再开启此选项。",
                confirmTitle: "打开系统设置",
                cancelTitle: "暂不开启",
                action: openSystemSettings
            )
            .pickupPrompt(
                isPresented: $showingActivityError,
                title: "实时动态未开启",
                message: activityStatus,
                confirmTitle: "打开系统设置",
                cancelTitle: "稍后再说",
                action: openSystemSettings
            )
            .pickupPrompt(
                isPresented: $showingClearError,
                title: "清理失败",
                message: "历史记录没有清除，请稍后重试。",
                confirmTitle: "知道了",
                cancelTitle: nil
            ) {}
            .pickupPrompt(
                isPresented: $showingSampleError,
                title: "示例数据操作失败",
                message: "示例数据没有更新，请稍后重试。",
                confirmTitle: "知道了",
                cancelTitle: nil
            ) {}
            .task {
                refreshActivityStatus()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                refreshActivityStatus()
                refreshActivity()
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshActivity() {
        Task {
            let result = await PickupActivityManager.refresh(context: modelContext)
            activityPermissionEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            activityStatus = result.message
            if case .systemDisabled = result {
                showingActivityError = liveActivitiesEnabled
            }
            if case .failed = result {
                showingActivityError = liveActivitiesEnabled
            }
        }
    }

    private func refreshActivityStatus() {
        activityPermissionEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        if !activityPermissionEnabled {
            activityStatus = "系统设置未允许"
            return
        }
        activityStatus = liveActivitiesEnabled ? "可用" : "已关闭"
    }

    private func updateNotificationPreference(_ enabled: Bool) {
        guard enabled else {
            notificationsEnabled = false
            PickupNotificationManager.cancelPendingNotifications()
            return
        }
        Task {
            let granted = await PickupNotificationManager.requestPermission()
            notificationsEnabled = granted
            showingNotificationDenied = !granted
        }
    }

    private func clearHistory() {
        do {
            try PickupStore.clearCompleted(in: modelContext)
        } catch {
            showingClearError = true
        }
    }

    private func addSamples() {
        do {
            try PickupStore.addSampleData(in: modelContext)
            Task { await PickupActivityManager.refresh(context: modelContext) }
        } catch {
            showingSampleError = true
        }
    }

    private func clearSamples() {
        do {
            try PickupStore.clearSampleData(in: modelContext)
            Task { await PickupActivityManager.refresh(context: modelContext) }
        } catch {
            showingSampleError = true
        }
    }
}

struct PickupShortcutGuideView: View {
    var onFinish: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("只需设置一次。之后符合条件的新短信会传给取件 App，在本机识别驿站和取件码。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("创建短信自动化") {
                    guideStep(1, title: "打开快捷指令", detail: "点底部“自动化”，再点右上角“＋”，选择“创建个人自动化”。")
                    guideStep(2, title: "选择短信触发条件", detail: "在触发条件列表中选“信息”。可以按发件人筛选；第一次设置建议先不筛选，避免漏掉测试短信。")
                    guideStep(3, title: "添加取件动作", detail: "点“下一步”后添加操作，搜索并选择“添加取件短信”。如果列表里没有，先打开一次“取件” App，再回到快捷指令搜索。")
                    guideStep(4, title: "传入短信正文", detail: "点动作里的“短信内容”参数，选择上一条自动化触发器提供的“信息”变量（魔法变量）。这样 App 才能读取并解析短信正文。")
                    guideStep(5, title: "保存并运行", detail: "点“下一步”并存储自动化。系统询问运行方式时可选立即运行；初次测试也可保留运行前确认。")
                }

                Section("测试和隐私") {
                    Text("先用一条包含驿站名称和取件码的测试短信触发自动化，也可以在 App 首页点“＋”手动添加。示例数据只用于体验界面。")
                    Text("短信内容由你设置的快捷指令传入，只在本机解析和保存；App 不会扫描短信，也不会上传内容。")
                        .foregroundStyle(.secondary)
                    if let shortcutsURL = URL(string: "shortcuts://") {
                        Link(destination: shortcutsURL) {
                            Label("现在打开快捷指令", systemImage: "arrow.up.forward.app")
                        }
                    }
                }
            }
            .navigationTitle("添加快捷指令")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onFinish {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("进入 App", action: onFinish)
                    }
                }
            }
        }
    }

    private func guideStep(_ number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
        .listRowSeparator(.hidden)
    }
}

private struct PickupDetailCard: View {
    @State private var showingDeleteConfirmation = false
    let item: PickupItem
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("取件码", systemImage: "number")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                Text("待取")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(item.code)
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Text("收到：\(item.receivedAt.formatted(date: .omitted, time: .shortened))")
                if !item.courierName.isEmpty { Text("· \(item.courierName)") }
                if item.source == "demo" { Text("示例") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = item.code
                } label: {
                    Label("复制取件码", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)

                PickupCompleteButton(code: item.code, action: onComplete)
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button("标记为已取", systemImage: "checkmark.circle.fill", action: onComplete)
            Button("删除记录", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .pickupPrompt(
            isPresented: $showingDeleteConfirmation,
            title: "删除这条取件记录？",
            message: "取件码 \(item.code) 将被删除，此操作无法撤销。",
            confirmTitle: "删除记录",
            isDestructive: true,
            action: onDelete
        )
    }
}

private struct PickupHistoryRow: View {
    @State private var showingDeleteConfirmation = false
    let item: PickupItem
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.stationName)
                    .font(.headline)
                Spacer()
                Text((item.completedAt ?? item.receivedAt).formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.code)
                .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("已取")
                if !item.courierName.isEmpty { Text("· \(item.courierName)") }
                if item.source == "demo" { Text("· 示例") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button("复制取件码", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = item.code
            }
            Button("删除记录", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .pickupPrompt(
            isPresented: $showingDeleteConfirmation,
            title: "删除这条历史记录？",
            message: "取件码 \(item.code) 的历史记录将被删除，此操作无法撤销。",
            confirmTitle: "删除记录",
            isDestructive: true,
            action: onDelete
        )
    }
}

private struct PickupCompleteButton: View {
    let code: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .systemBackground).opacity(0.72), in: Circle())
                .overlay { Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.8) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("标记为已取")
        .accessibilityValue(code)
    }
}

private struct PickupCodeRow: View {
    let item: PickupItem
    let onComplete: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var copied = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.code)
                    .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .textSelection(.enabled)
                HStack(spacing: 7) {
                    if !item.courierName.isEmpty { Text(item.courierName) }
                    Text(item.receivedAt.formatted(date: .omitted, time: .shortened))
                    if item.source == "demo" { Text("示例") }
                    if copied { Text("已复制").foregroundStyle(.green) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Button(action: copyCode) {
                    Image(systemName: copied ? "doc.on.doc.fill" : "doc.on.doc")
                        .font(.body.weight(.medium))
                        .foregroundStyle(copied ? Color.green : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .systemBackground).opacity(0.72), in: Circle())
                        .overlay { Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.8) }
                }
                .accessibilityLabel(copied ? "已复制" : "复制取件码")
                .accessibilityValue(item.code)

                if let onComplete {
                    PickupCompleteButton(code: item.code, action: onComplete)
                }
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("复制取件码", systemImage: "doc.on.doc", action: copyCode)
            if let onComplete {
                Button("标记为已取", systemImage: "checkmark", action: onComplete)
            }
            if onDelete != nil {
                Button("删除记录", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .pickupPrompt(
            isPresented: $showingDeleteConfirmation,
            title: "删除这条取件记录？",
            message: "取件码 \(item.code) 将被删除，此操作无法撤销。",
            confirmTitle: "删除记录",
            isDestructive: true
        ) {
            onDelete?()
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = item.code
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}

private func stationSymbol(for name: String) -> String {
    if name.contains("丰巢") || name.contains("柜") { return "shippingbox" }
    return "building.2"
}

private func dayTitle(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "今天" }
    if calendar.isDateInYesterday(date) { return "昨天" }
    return date.formatted(.dateTime.year().month().day())
}

extension View {
    /// 所有应用内提示使用底部面板，避免系统确认菜单根据锚点显示到页面顶部。
    func pickupPrompt(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        isDestructive: Bool = false,
        cancelTitle: String? = "取消",
        action: @escaping () -> Void
    ) -> some View {
        modifier(PickupPromptModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive,
            cancelTitle: cancelTitle,
            action: action
        ))
    }
}

private struct PickupPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didConfirm = false
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let cancelTitle: String?
    let action: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            // 等面板关闭再删除记录或弹出错误提示，避免承载面板的行先被移除。
            guard didConfirm else { return }
            didConfirm = false
            action()
        }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        Button(role: isDestructive ? .destructive : nil) {
                            didConfirm = true
                            isPresented = false
                        } label: {
                            Text(confirmTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(.white)
                                .background(isDestructive ? Color.red : Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        if let cancelTitle {
                            Button(role: .cancel) {
                                isPresented = false
                            } label: {
                                Text(cancelTitle)
                                    .font(.body.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .foregroundStyle(.primary)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 20)
            }
            .onAppear { didConfirm = false }
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(320), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationCompactAdaptation(.sheet)
        }
    }
}
