import Foundation
import SwiftData
import UserNotifications

@MainActor
enum PickupStore {
    static let appGroupID = PickupWidgetSnapshot.appGroupID

    static let container: ModelContainer = {
        let schema = Schema([PickupItem.self])
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            let sharedConfiguration = ModelConfiguration(
                "Pickup",
                schema: schema,
                groupContainer: .identifier(appGroupID)
            )
            do {
                return try ModelContainer(for: schema, configurations: [sharedConfiguration])
            } catch {
                // 共享存储创建失败时改用 App 私有目录，保证本地记录仍可使用。
            }
        }

        let localConfiguration = ModelConfiguration("PickupLocal", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("无法创建本地数据容器：\(error.localizedDescription)")
        }
    }()

    @discardableResult
    static func addMessage(_ message: String, in context: ModelContext) throws -> Int {
        guard let parsed = PickupParser.parse(message) else { return 0 }
        let fingerprint = makeFingerprint(message)
        let descriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.fingerprint == fingerprint }
        )
        guard try context.fetch(descriptor).isEmpty else { return 0 }

        for code in parsed.codes {
            context.insert(PickupItem(
                rawMessage: message,
                stationName: parsed.stationName,
                stationAddress: parsed.stationAddress,
                courierName: parsed.courierName,
                code: code,
                fingerprint: fingerprint,
                confidence: parsed.confidence
            ))
        }
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
        return parsed.codes.count
    }

    static func markCompleted(_ item: PickupItem, in context: ModelContext) throws {
        item.status = .completed
        item.completedAt = .now
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
    }

    static func markCompleted(_ items: [PickupItem], in context: ModelContext) throws {
        for item in items where item.status == .waiting {
            item.status = .completed
            item.completedAt = .now
        }
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
    }

    static func delete(_ item: PickupItem, in context: ModelContext) throws {
        context.delete(item)
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
    }

    static func addManual(
        code: String,
        stationName: String,
        stationAddress: String,
        courierName: String,
        in context: ModelContext
    ) throws -> Bool {
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanedName = stationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAddress = stationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCourier = courierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedCode.isEmpty, !cleanedName.isEmpty else { return false }
        let rawMessage = [cleanedName, cleanedAddress, cleanedCode].filter { !$0.isEmpty }.joined(separator: "\n")
        let fingerprint = makeFingerprint("manual|\(cleanedName)|\(cleanedAddress)|\(cleanedCode)")
        let descriptor = FetchDescriptor<PickupItem>(predicate: #Predicate { $0.fingerprint == fingerprint })
        guard try context.fetch(descriptor).isEmpty else { return false }
        context.insert(PickupItem(
            rawMessage: rawMessage,
            stationName: cleanedName,
            stationAddress: cleanedAddress,
            courierName: cleanedCourier,
            code: cleanedCode,
            fingerprint: fingerprint,
            source: "manual"
        ))
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
        return true
    }

    @discardableResult
    static func addSampleData(in context: ModelContext) throws -> Int {
        let demoDescriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.source == "demo" }
        )
        guard try context.fetch(demoDescriptor).isEmpty else { return 0 }

        let now = Date.now
        let samples: [(station: String, address: String, courier: String, code: String, received: Date, completed: Bool)] = [
            ("星河小区东门驿站", "星河小区东门", "中通", "6-5218", now.addingTimeInterval(-1_800), false),
            ("星河小区东门驿站", "星河小区东门", "圆通", "382917", now.addingTimeInterval(-7_200), false),
            ("丰巢快递柜", "3号楼下", "顺丰", "7315", now.addingTimeInterval(-14_400), false),
            ("花园路妈妈驿站", "花园路 18 号", "韵达", "A1298", now.addingTimeInterval(-86_400), true),
            ("菜鸟驿站", "星河小区东门", "中通", "QX4821", now.addingTimeInterval(-1_200), false),
            ("丰巢", "3号楼下", "丰巢", "7316", now.addingTimeInterval(-900), false),
            ("丰巢", "3号楼下", "丰巢", "A9502", now.addingTimeInterval(-600), false),
            ("妈妈驿站", "花园路", "圆通", "482913", now.addingTimeInterval(-300), false)
        ]

        for sample in samples {
            let rawMessage = "【\(sample.courier)】\(sample.station) 取件码：\(sample.code)"
            let item = PickupItem(
                rawMessage: rawMessage,
                stationName: sample.station,
                stationAddress: sample.address,
                courierName: sample.courier,
                code: sample.code,
                receivedAt: sample.received,
                fingerprint: makeFingerprint("demo|\(sample.station)|\(sample.code)"),
                source: "demo"
            )
            if sample.completed {
                item.status = .completed
                item.completedAt = now.addingTimeInterval(-3_600)
            }
            context.insert(item)
        }
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
        return samples.count
    }

    static func clearSampleData(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<PickupItem>(
            predicate: #Predicate { $0.source == "demo" }
        )
        for item in try context.fetch(descriptor) { context.delete(item) }
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
    }

    static func clearCompleted(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<PickupItem>(predicate: #Predicate { $0.statusRawValue == "completed" })
        for item in try context.fetch(descriptor) { context.delete(item) }
        try context.save()
        PickupWidgetSnapshotWriter.refresh(context: context)
    }

    private static func makeFingerprint(_ message: String) -> String {
        // 用稳定摘要做本地去重，不把短信正文写入日志或外部服务。
        let normalized = message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return normalized.unicodeScalars.reduce(into: UInt64(14_695_981_039_346_656_037)) { hash, scalar in
            hash = (hash ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }.description
    }
}

@MainActor
enum PickupNotificationManager {
    private static let enabledKey = "pickup.notifications.enabled"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func sendNewPickup(stationName: String, codes: [String]) async {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "新增取件码"
        content.subtitle = stationName
        content.body = codes.prefix(3).joined(separator: " · ")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }
}
