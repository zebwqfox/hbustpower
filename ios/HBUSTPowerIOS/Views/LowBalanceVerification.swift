#if DEBUG
import UIKit
import UserNotifications

@MainActor
private final class FakePowerNotificationCenter: PowerNotificationCenter {
    enum Failure: Error { case unavailable }
    var status: UNAuthorizationStatus = .authorized
    var grant = true
    var authorizationFails = false
    var submissionFails = false
    var delaySubmission = false
    var authorizationRequests = 0
    var submissionAttempts = 0
    var requests: [UNNotificationRequest] = []
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        if authorizationFails { throw Failure.unavailable }
        status = grant ? .authorized : .denied
        return grant
    }
    func submit(_ request: UNNotificationRequest) async throws {
        submissionAttempts += 1
        if delaySubmission { try await Task.sleep(for: .milliseconds(40)) }
        if submissionFails { throw Failure.unavailable }
        requests.append(request)
    }
}

@MainActor
private final class NotificationReceipt { var request: UNNotificationRequest? }

@MainActor
enum LowBalanceVerification {
    static func run() {
        guard CommandLine.arguments.contains("--verify-alerts") || CommandLine.arguments.contains("--verify-system-alert") else { return }
        Task { @MainActor in
            if CommandLine.arguments.contains("--verify-alerts") { await runCases() }
            if CommandLine.arguments.contains("--verify-system-alert") { await runSystemDelivery() }
        }
    }

    private static func runCases() async {
        var suites: [String] = []
        var passes = 0
        @MainActor func fixture() -> (LowBalanceReminder, FakePowerNotificationCenter, UserDefaults) {
            let suite = "hbust-alert-verification." + UUID().uuidString
            suites.append(suite)
            let defaults = UserDefaults(suiteName: suite)!
            let center = FakePowerNotificationCenter()
            return (LowBalanceReminder(defaults: defaults, center: center), center, defaults)
        }
        @MainActor func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            precondition(condition(), "ALERT_CHECK FAILED: " + name)
            passes += 1
            print("ALERT_CHECK PASS: " + name)
        }
        defer { for suite in suites { UserDefaults.standard.removePersistentDomain(forName: suite) } }

        do {
            let (reminder, center, _) = fixture()
            await reminder.evaluate(balance: 50, threshold: 20, room: "A")
            await reminder.evaluate(balance: 20, threshold: 20, room: "A")
            check(center.requests.isEmpty && center.authorizationRequests == 0, "高于或等于阈值不提醒")
            await reminder.evaluate(balance: 19.99, threshold: 20, room: "A")
            check(center.requests.count == 1, "从20度降至19.99度提醒一次")
            check(center.requests[0].content.title == "宿舍电量偏低" && center.requests[0].content.body.contains("19.99") && center.requests[0].content.sound != nil, "通知标题、精确电量和声音配置正确")
            await reminder.evaluate(balance: 18, threshold: 20, room: "A")
            await reminder.evaluate(balance: 17, threshold: 20, room: "A")
            check(center.requests.count == 1, "持续低电量重复刷新不轰炸通知")
            await reminder.evaluate(balance: 100, threshold: 20, room: "A")
            await reminder.evaluate(balance: 19, threshold: 20, room: "A")
            check(center.requests.count == 2, "充值回升后再次变低重新提醒")
        }
        do {
            let (reminder, center, _) = fixture()
            await reminder.evaluate(balance: 12.5, threshold: 20, room: "A")
            check(center.requests.count == 1, "首次读取就是低电量也提醒")
        }
        do {
            let (reminder, center, _) = fixture()
            center.status = .notDetermined
            await reminder.evaluate(balance: 12.5, threshold: 20, room: "A")
            check(center.authorizationRequests == 1 && center.requests.count == 1, "首次授权允许后发送通知")
        }
        do {
            let (reminder, center, _) = fixture()
            center.status = .notDetermined
            center.grant = false
            await reminder.evaluate(balance: 19, threshold: 20, room: "A")
            await reminder.evaluate(balance: 18, threshold: 20, room: "A")
            check(center.authorizationRequests == 1 && center.requests.isEmpty, "拒绝权限后不发送、不反复弹窗")
            center.status = .authorized
            await reminder.evaluate(balance: 17, threshold: 20, room: "A")
            check(center.requests.count == 1, "后来开启权限且电量持续偏低仍会补发")
        }
        for status: UNAuthorizationStatus in [.provisional, .ephemeral] {
            let (reminder, center, _) = fixture()
            center.status = status
            await reminder.evaluate(balance: 12.5, threshold: 20, room: "A")
            check(center.requests.count == 1 && center.authorizationRequests == 0, "权限状态\(status.rawValue)可发送且不重复申请")
        }
        do {
            let (reminder, center, _) = fixture()
            center.submissionFails = true
            await reminder.evaluate(balance: 19, threshold: 20, room: "A")
            check(center.requests.isEmpty && reminder.lastError != nil, "发送失败保留错误、不消耗提醒")
            center.submissionFails = false
            await reminder.evaluate(balance: 18, threshold: 20, room: "A")
            check(center.requests.count == 1 && center.submissionAttempts == 2 && reminder.lastError == nil, "发送失败后下次刷新可重试")
        }
        do {
            let (reminder, center, _) = fixture()
            center.status = .notDetermined
            center.authorizationFails = true
            await reminder.evaluate(balance: 19, threshold: 20, room: "A")
            center.authorizationFails = false
            await reminder.evaluate(balance: 18, threshold: 20, room: "A")
            check(center.requests.count == 1 && center.authorizationRequests == 2, "授权接口失败后可重试")
        }
        do {
            let (reminder, center, defaults) = fixture()
            await reminder.evaluate(balance: 19, threshold: 20, room: "A")
            let restarted = LowBalanceReminder(defaults: defaults, center: center)
            await restarted.evaluate(balance: 18, threshold: 20, room: "A")
            check(center.requests.count == 1, "重启应用仍记得已提醒、不重复发送")
            await restarted.evaluate(balance: 18, threshold: 30, room: "A")
            check(center.requests.count == 2, "修改提醒值后按新阈值判断")
            await restarted.evaluate(balance: 18, threshold: 30, room: "B")
            check(center.requests.count == 3, "切换宿舍不沿用旧宿舍的已提醒状态")
            restarted.reset()
            await restarted.evaluate(balance: 17, threshold: 30, room: "B")
            check(center.requests.count == 4, "清除账户状态后可重新提醒")
        }
        do {
            let (reminder, center, _) = fixture()
            for threshold in [0.0, -1, .nan, .infinity] {
                await reminder.evaluate(balance: 12.5, threshold: threshold, room: "A")
            }
            for balance in [Double.nan, .infinity, -.infinity] {
                await reminder.evaluate(balance: balance, threshold: 20, room: "A")
            }
            check(center.requests.isEmpty, "非法阈值与非数值电量不产生通知")
            await reminder.evaluate(balance: 0, threshold: 20, room: "A")
            check(center.requests.count == 1, "零电量会提醒")
            reminder.reset()
            await reminder.evaluate(balance: -1, threshold: 20, room: "A")
            check(center.requests.count == 2, "负电量会提醒")
        }
        do {
            let (reminder, center, _) = fixture()
            center.delaySubmission = true
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<10 { group.addTask { await reminder.evaluate(balance: 12.5, threshold: 20, room: "A") } }
            }
            check(center.requests.count == 1, "10次并发检查仅发送一次")
        }
        do {
            let (reminder, center, defaults) = fixture()
            let model = AppModel(defaults: defaults, reminder: reminder)
            await model.applyLowBalanceTestReading(30)
            await model.applyLowBalanceTestReading(12.5)
            check(model.snapshot?.purchasedKWh == 12.5 && model.status == .ready && center.requests.count == 1, "真实AppModel更新链路触发低电量提醒")
            model.lowBalanceThreshold = .infinity
            model.lowBalanceThreshold = -10
            check(model.lowBalanceThreshold == 20, "设置层拒绝非法提醒阈值")
        }
        do {
            let (_, center, _) = fixture()
            center.status = .notDetermined
            await PowerNotificationPermission.requestIfNeeded(using: center)
            check(center.authorizationRequests == 1 && center.status == .authorized, "首次启动在加载数据前申请通知权限")
            await PowerNotificationPermission.requestIfNeeded(using: center)
            check(center.authorizationRequests == 1, "已授权再次启动不重复申请")
        }
        do {
            let (_, center, _) = fixture()
            center.status = .notDetermined
            center.grant = false
            await PowerNotificationPermission.requestIfNeeded(using: center)
            await PowerNotificationPermission.requestIfNeeded(using: center)
            check(center.authorizationRequests == 1 && center.status == .denied, "启动时拒绝可继续且下次不重复弹窗")
        }
        print("ALERT_CHECK COMPLETE: \(passes) checks passed")
    }

    private static func runSystemDelivery() async {
        let center = UNUserNotificationCenter.current()
        do {
            // Test-only provisional permission exercises the real iOS delivery service without a permission dialog.
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
            guard allowed else { print("SYSTEM_ALERT_CHECK BLOCKED: simulator notification permission denied"); return }
            let suite = "hbust-alert-system-test." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
            let existingIDs = Set(await center.deliveredNotifications().map { $0.request.identifier })
            let reminder = LowBalanceReminder(defaults: defaults)
            let model = AppModel(defaults: defaults, reminder: reminder)
            let receipt = NotificationReceipt()
            let observer = NotificationCenter.default.addObserver(forName: Notification.Name("powerTestNotificationPresented"), object: nil, queue: .main) { notification in
                MainActor.assumeIsolated { receipt.request = notification.object as? UNNotificationRequest }
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            try await Task.sleep(for: .seconds(1))
            await model.applyLowBalanceTestReading(30)
            await model.applyLowBalanceTestReading(12.5)
            for _ in 0..<30 {
                if receipt.request != nil { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let delivered = await center.deliveredNotifications()
            let matching = receipt.request ?? delivered.first { !existingIDs.contains($0.request.identifier) && $0.request.content.body.contains("12.50") }?.request
            precondition(matching?.content.title == "宿舍电量偏低", "System notification was not delivered")
            precondition(matching?.content.body.contains("12.50") == true)
            print("SYSTEM_ALERT_CHECK PASS: real iOS notification received via AppModel; body=\(matching!.content.body); authorization=provisional")
        } catch {
            preconditionFailure("SYSTEM_ALERT_CHECK FAILED: \(error)")
        }
    }
}
#endif
