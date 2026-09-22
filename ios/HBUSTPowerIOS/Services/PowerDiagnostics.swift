import UIKit
import UserNotifications

/// An in-memory, bounded log of explicit events; never stores URLs, tokens or cookie values.
@MainActor
final class PowerDiagnostics {
    static let shared = PowerDiagnostics()
    static let didChange = Notification.Name("powerDiagnosticsDidChange")
    private(set) var events: [String] = []

    func record(_ message: String) {
        events.append(Date().formatted(date: .omitted, time: .standard) + "  " + message)
#if DEBUG
        print("DIAG " + message)
#endif
        if events.count > 60 { events.removeFirst(events.count - 60) }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    static func errorSummary(_ error: Error) -> String {
        if let error = error as? ElectricityError { return error.localizedDescription }
        let value = error as NSError
        // Do not export localizedDescription or userInfo, which may contain an authenticated URL.
        return "错误代码 \(value.code)（\(value.domain == NSURLErrorDomain ? "网络" : "系统")）"
    }
}

@MainActor
final class DebugNotificationService {
    static let prefix = "debug-notification-"
    private let center = UNUserNotificationCenter.current()

    @discardableResult
    func send(after delay: TimeInterval, lowBalance: Bool = false) async throws -> String {
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard [.authorized, .provisional, .ephemeral].contains(status) else {
            throw DebugNotificationError.permissionDenied
        }
        let content = UNMutableNotificationContent()
        content.title = lowBalance ? "低电量提醒 · 测试" : "湖科电量 · 测试通知"
        content.body = lowBalance
            ? "模拟剩余 12.50 度，低于 20 度提醒值。这是测试，不会改变实际电量或提醒记录。"
            : (delay > 0 ? "延迟通知已送达，可用来检查后台和锁屏通知。" : "即时通知已送达，通知通道可以正常使用。")
        content.sound = .default
        let identifier = Self.prefix + UUID().uuidString
        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false) : nil
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        PowerDiagnostics.shared.record(lowBalance ? "低电量样式测试：系统已接受" : "通知测试：系统已接受，延迟 \(Int(delay)) 秒")
        return identifier
    }

    func clearTests() async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        let delivered = await center.deliveredNotifications().map { $0.request.identifier }.filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
        PowerDiagnostics.shared.record("已清除测试通知：待发送 \(pending.count)，已投递 \(delivered.count)")
    }
}

private enum DebugNotificationError: LocalizedError {
    case permissionDenied
    var errorDescription: String? { "通知权限已关闭，请在系统设置中允许通知。" }
}
