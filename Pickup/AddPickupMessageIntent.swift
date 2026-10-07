import AppIntents
import SwiftData

struct AddPickupMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "添加取件短信"
    static let description = IntentDescription("在本机识别短信中的驿站和取件码。")
    static let openAppWhenRun = false

    @Parameter(title: "短信内容")
    var message: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(value: "没有收到短信内容", dialog: "没有收到短信内容")
        }

        let context = ModelContext(PickupStore.container)
        let savedCount: Int
        do {
            savedCount = try PickupStore.addMessage(message, in: context)
        } catch {
            return .result(value: "保存失败，请稍后重试", dialog: "保存失败，请稍后重试")
        }
        guard savedCount > 0 else {
            let result = PickupParser.parse(message) == nil ? "没有发现明确的取件码" : "这条短信已添加过"
            return .result(value: result, dialog: IntentDialog(stringLiteral: result))
        }
        await PickupActivityManager.refresh(context: context)
        if let parsed = PickupParser.parse(message) {
            await PickupNotificationManager.sendNewPickup(stationName: parsed.stationName, codes: parsed.codes)
        }
        let result = "已添加 \(savedCount) 个取件码"
        return .result(value: result, dialog: "取件信息已保存")
    }
}

struct PickupShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPickupMessageIntent(),
            phrases: ["用\(.applicationName)添加取件短信", "添加取件短信到\(.applicationName)"],
            shortTitle: "添加取件短信",
            systemImageName: "shippingbox"
        )
    }
}
