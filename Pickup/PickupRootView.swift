import SwiftData
import SwiftUI

struct PickupRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PickupItem.receivedAt, order: .reverse) private var allItems: [PickupItem]
    @AppStorage("pickup.hasCompletedSetup") private var hasCompletedSetup = false
    @State private var selectedTab = 0
    @State private var homeSearch = ""
    @State private var historySearch = ""
    @State private var showingAddSheet = false
    @State private var showingShortcutGuide = false

    private var waitingItems: [PickupItem] {
        allItems.filter { $0.status == .waiting && matchesSearch($0, text: homeSearch) }
    }

    private var completedItems: [PickupItem] {
        allItems.filter { $0.status == .completed && matchesSearch($0, text: historySearch) }
    }

    var body: some View {
        Group {
            if hasCompletedSetup {
                mainContent
            } else {
                SetupWelcomeView { showingShortcutGuide = true }
            }
        }
        .task {
#if DEBUG && targetEnvironment(simulator)
            // 仅在 Debug 模拟器首次启动时加入示例，避免污染真机或发布版本。
            let didSeedDemoDataKey = "pickup.demoData.seeded"
            if !UserDefaults.standard.bool(forKey: didSeedDemoDataKey) {
                do {
                    try PickupStore.addSampleData(in: modelContext)
                    UserDefaults.standard.set(true, forKey: didSeedDemoDataKey)
                } catch {
                    // 保存失败时保留未完成标记，下次启动仍可重试。
                }
            }
#endif
            await PickupActivityManager.refresh(context: modelContext)
        }
        .sheet(isPresented: $showingShortcutGuide) {
            PickupShortcutGuideView {
                hasCompletedSetup = true
                selectedTab = 2
                showingShortcutGuide = false
            }
            .interactiveDismissDisabled()
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            PickupHomeView(
                items: waitingItems,
                searchText: $homeSearch,
                onAdd: { showingAddSheet = true },
                onComplete: markCompleted,
                onDelete: deleteItem,
                onCompleteAll: markCompleted
            )
            .tabItem { Label("取件", systemImage: "shippingbox") }
            .tag(0)

            PickupHistoryView(
                items: completedItems,
                searchText: $historySearch,
                onDelete: deleteItem
            )
            .tabItem { Label("历史", systemImage: "clock") }
            .tag(1)

            PickupSettingsView(
                waitingCount: allItems.filter { $0.status == .waiting }.count,
                completedCount: allItems.filter { $0.status == .completed }.count,
                sampleCount: allItems.filter { $0.source == "demo" }.count
            )
            .tabItem { Label("设置", systemImage: "gearshape") }
            .tag(2)
        }
        .tint(.primary)
        .sheet(isPresented: $showingAddSheet) {
            ManualAddView { station, code in
                Task {
                    await PickupActivityManager.refresh(context: modelContext)
                    await PickupNotificationManager.sendNewPickup(stationName: station, codes: [code])
                }
            }
        }
    }

    private func matchesSearch(_ item: PickupItem, text: String) -> Bool {
        guard !text.isEmpty else { return true }
        return item.code.localizedCaseInsensitiveContains(text)
            || item.stationName.localizedCaseInsensitiveContains(text)
            || item.stationAddress.localizedCaseInsensitiveContains(text)
            || item.courierName.localizedCaseInsensitiveContains(text)
    }

    private func markCompleted(_ item: PickupItem) {
        do {
            try PickupStore.markCompleted(item, in: modelContext)
            Task { await PickupActivityManager.refresh(context: modelContext) }
        } catch {
            // 保存失败时保留原状态，避免界面与本地数据库不一致。
        }
    }

    private func markCompleted(_ items: [PickupItem]) {
        do {
            try PickupStore.markCompleted(items, in: modelContext)
            Task { await PickupActivityManager.refresh(context: modelContext) }
        } catch {
            // 批量操作失败时保留所有记录，方便用户稍后重试。
        }
    }

    private func deleteItem(_ item: PickupItem) {
        do {
            try PickupStore.delete(item, in: modelContext)
            Task { await PickupActivityManager.refresh(context: modelContext) }
        } catch {
            // 删除失败时不从当前列表隐藏记录。
        }
    }

}

private struct SetupWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 54, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(spacing: 10) {
                Text("取件，简单一点")
                    .font(.largeTitle.weight(.semibold))
                Text("自动整理短信里的取件码，\n按驿站帮你放好。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onContinue) {
                Text("开始设置")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}

private struct ManualAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code = ""
    @State private var stationName = ""
    @State private var address = ""
    @State private var courier = ""
    @State private var errorMessage: String?

    let onSaved: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("取件信息") {
                    TextField("取件码", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("驿站名称", text: $stationName)
                    TextField("地址（选填）", text: $address)
                    TextField("快递公司（选填）", text: $courier)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("手动添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || stationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            let saved = try PickupStore.addManual(
                code: code,
                stationName: stationName,
                stationAddress: address,
                courierName: courier,
                in: modelContext
            )
            guard saved else {
                errorMessage = "这条记录已存在，请检查取件码和驿站。"
                return
            }
            onSaved(stationName.trimmingCharacters(in: .whitespacesAndNewlines),
                    code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            dismiss()
        } catch {
            errorMessage = "保存失败，请稍后重试。"
        }
    }
}
