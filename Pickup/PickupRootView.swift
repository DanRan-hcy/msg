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
    @State private var messageText = ""
    @State private var code = ""
    @State private var stationName = ""
    @State private var address = ""
    @State private var courier = ""
    @State private var errorMessage: String?
    @State private var didRecognizeMessage = false

    let onSaved: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $messageText)
                            .frame(minHeight: 112)
                            .scrollContentBackground(.hidden)
                            .onChange(of: messageText) { _, newValue in
                                // 粘贴短信后自动尝试识别，输入过短时不打断用户填写。
                                guard newValue.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else { return }
                                recognizeMessage(showFailure: false)
                            }
                        if messageText.isEmpty {
                            Text("粘贴完整的取件短信，App 会自动识别取件码和驿站")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    Button {
                        recognizeMessage(showFailure: true)
                    } label: {
                        Label(didRecognizeMessage ? "已识别，可继续修改" : "识别短信内容", systemImage: didRecognizeMessage ? "checkmark.circle" : "wand.and.stars")
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("粘贴短信")
                } footer: {
                    Text("支持直接粘贴短信全文，也可以在下面手动填写。")
                }

                Section("取件信息") {
                    TextField("取件码", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("驿站名称", text: $stationName)
                    TextField("地址（选填）", text: $address)
                    TextField("快递公司（选填）", text: $courier)
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
            .alert("无法添加", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请检查输入内容后重试。")
            }
        }
    .presentationDetents([.medium, .large])
    }

    private func recognizeMessage(showFailure: Bool) {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard let result = PickupParser.parse(message), let firstCode = result.codes.first else {
            if showFailure { errorMessage = "没有识别到明确的取件码，请检查短信内容或手动填写。" }
            return
        }
        code = firstCode
        stationName = result.stationName
        address = result.stationAddress
        courier = result.courierName
        errorMessage = result.codes.count > 1 ? "识别到多个取件码，当前先填入第一个：\(firstCode)" : nil
        didRecognizeMessage = true
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
