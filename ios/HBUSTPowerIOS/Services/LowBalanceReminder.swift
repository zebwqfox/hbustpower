import Foundation
import UIKit
import UserNotifications

@MainActor
protocol PowerNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func submit(_ request: UNNotificationRequest) async throws
}

@MainActor
final class SystemPowerNotificationCenter: PowerNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws -> Bool {
        let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if allowed { UIApplication.shared.registerForRemoteNotifications() }
        return allowed
    }
    func submit(_ request: UNNotificationRequest) async throws { try await center.add(request) }
}

/// Remembers successful submissions, rather than merely remembering a low reading.
/// Failed or unauthorized attempts remain eligible on the next successful refresh.
@MainActor
final class LowBalanceReminder {
    private let defaults: UserDefaults
    private let center: PowerNotificationCenter
    private let stateKey = "lowBalanceReminder.lastSubmission.v1"
    private var pending: Task<Void, Never>?
    private var generation = 0
    private(set) var lastError: String?
    var diagnosticStatus: String {
        if let lastError { return "发送失败：" + lastError }
        if defaults.dictionary(forKey: stateKey) != nil { return "本轮低电量已提醒；回升后重新启用" }
        return "本轮尚未发送低电量提醒"
    }

    init(defaults: UserDefaults = .standard, center: PowerNotificationCenter? = nil) {
        self.defaults = defaults
        self.center = center ?? SystemPowerNotificationCenter()
    }

    func evaluate(balance: Double, threshold: Double, room: String?) async {
        guard !Task.isCancelled, balance.isFinite, threshold.isFinite, threshold > 0 else { return }
        // Serialize permission prompts and submissions, including overlapping refreshes.
        let previous = pending
        let expectedGeneration = generation
        let task = Task { @MainActor in
            await previous?.value
            guard self.generation == expectedGeneration else { return }
            await self.process(balance: balance, threshold: threshold, room: room ?? "", generation: expectedGeneration)
        }
        pending = task
        await task.value
    }

    func reset() {
        generation += 1
        defaults.removeObject(forKey: stateKey)
        lastError = nil
    }

    private func process(balance: Double, threshold: Double, room: String, generation: Int) async {
        guard balance < threshold else {
            if defaults.dictionary(forKey: stateKey) != nil { PowerDiagnostics.shared.record("电量已回升，重新启用低电量提醒") }
            defaults.removeObject(forKey: stateKey)
            lastError = nil
            return
        }
        if let sent = defaults.dictionary(forKey: stateKey),
           sent["room"] as? String == room, sent["threshold"] as? Double == threshold {
            PowerDiagnostics.shared.record("低电量提醒：本轮已发送，跳过重复提醒")
            return
        }
        do {
            let status = await center.authorizationStatus()
            let allowed: Bool
            switch status {
            case .authorized, .provisional, .ephemeral: allowed = true
            case .notDetermined: allowed = defaults.bool(forKey: "notificationPermission.deferred") ? false : try await center.requestAuthorization()
            default: allowed = false
            }
            guard self.generation == generation else { return }
            guard allowed else {
                PowerDiagnostics.shared.record("低电量提醒：通知权限未允许，保留下次尝试")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "宿舍电量偏低"
            content.body = String(format: "当前剩余 %.2f 度，低于 %.0f 度提醒值。", balance, threshold)
            content.sound = .default
            let request = UNNotificationRequest(identifier: "low-balance-" + UUID().uuidString, content: content, trigger: nil)
            try await center.submit(request)
            guard self.generation == generation else { return }
            defaults.set(["room": room, "threshold": threshold], forKey: stateKey)
            lastError = nil
            PowerDiagnostics.shared.record("低电量提醒：系统已接受")
        } catch {
            // A submission error must not consume the reminder; the next refresh retries.
            lastError = PowerDiagnostics.errorSummary(error)
            PowerDiagnostics.shared.record("低电量提醒失败：" + (lastError ?? "未知"))
        }
    }
}

@MainActor
enum PowerNotificationPermission {
    /// Ask once before the first data load. Denial never prevents using the app.
    static func requestIfNeeded(using center: PowerNotificationCenter) async {
        guard await center.authorizationStatus() == .notDetermined else { return }
        do { _ = try await center.requestAuthorization() }
        catch { /* Keep the system's not-determined state eligible for a later attempt. */ }
    }
}
