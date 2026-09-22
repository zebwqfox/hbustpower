import Foundation
import UserNotifications

@MainActor
final class FirstRunFlow {
    enum Step { case permission, permissionDenied, introduction, finished }
    static let completedKey = "firstRun.completed.v1"
    private let defaults: UserDefaults
    private let center: PowerNotificationCenter
    private(set) var step: Step = .permission
    private(set) var busy = false
    private(set) var error: String?
    init(defaults: UserDefaults = .standard, center: PowerNotificationCenter? = nil) {
        self.defaults = defaults; self.center = center ?? SystemPowerNotificationCenter()
    }
    func requestPermission() async {
        guard !busy, step != .finished else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            var status = await center.authorizationStatus()
            if status == .notDetermined {
                _ = try await center.requestAuthorization()
                status = await center.authorizationStatus()
            }
            switch status {
            case .authorized, .provisional, .ephemeral: step = .introduction
            case .denied: step = .permissionDenied
            default: error = "未能完成授权，请重试"
            }
        } catch { self.error = "未能申请通知权限，请重试" }
    }
    func continueWithoutPermission() {
        guard !busy else { return }
        defaults.set(true, forKey: "notificationPermission.deferred")
        step = .introduction; error = nil
    }
    func refreshAuthorization() async {
        guard !busy, step == .permissionDenied else { return }
        let status = await center.authorizationStatus()
        if [.authorized, .provisional, .ephemeral].contains(status) { step = .introduction }
    }
    func back() { guard !busy else { return }; step = .permission; error = nil }
    func finish() {
        guard step == .introduction, !busy else { return }
        defaults.set(true, forKey: Self.completedKey)
        step = .finished
    }
}
