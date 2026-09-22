#if DEBUG
import UIKit
import UserNotifications

@MainActor
enum StartupDebugVerification {
    @MainActor private final class Receipts { var ids: Set<String> = [] }
    static func run() {
        if CommandLine.arguments.contains("--verify-startup") { verifyStartup() }
        if CommandLine.arguments.contains("--verify-debug-notifications") {
            Task { await verifyNotifications() }
        }
    }

    private static func verifyStartup() {
        let model = AppModel()
        let overview = OverviewViewController(model: model)
        overview.loadViewIfNeeded()
        func find(_ id: String, in view: UIView) -> UIView? {
            if view.accessibilityIdentifier == id { return view }
            return view.subviews.lazy.compactMap { find(id, in: $0) }.first
        }
        let login = find("overview.login", in: overview.view)!
        let connection = find("overview.connection", in: overview.view)!
        let dashboard = find("overview.dashboard", in: overview.view)!
        func expect(_ name: String, loginVisible: Bool, dashboardVisible: Bool = false) {
            precondition(login.isHidden != loginVisible, name + ": login visibility")
            precondition(dashboard.isHidden != dashboardVisible, name + ": dashboard visibility")
            precondition(connection.isHidden == (loginVisible || dashboardVisible), name + ": connection visibility")
            print("STARTUP_CHECK PASS: " + name)
        }
        expect("首次渲染不显示登录", loginVisible: false)
        model.setVerificationState(.loading)
        expect("恢复登录时不显示登录", loginVisible: false)
        model.setVerificationState(.error("网络超时"))
        expect("网络失败保留重试页", loginVisible: false)
        model.setVerificationState(.authenticationRequired)
        expect("确认失效才显示登录", loginVisible: true)
        model.setVerificationState(.loading)
        expect("重新连接离开登录页", loginVisible: false)
        model.start() // --ui-preview supplies an offline, authenticated snapshot.
        expect("恢复成功直接显示电量", loginVisible: false, dashboardVisible: true)
        model.setVerificationState(.loading, keepSnapshot: true)
        expect("刷新保留已有电量", loginVisible: false, dashboardVisible: true)
        model.setVerificationState(.error("网络超时"), keepSnapshot: true)
        expect("刷新失败保留已有电量", loginVisible: false, dashboardVisible: true)
        model.setVerificationState(.authenticationRequired, keepSnapshot: true)
        expect("过期数据保留并显示重新登录按钮", loginVisible: false, dashboardVisible: true)
        let settings = SettingsViewController(model: model)
        let navigation = UINavigationController(rootViewController: settings)
        settings.loadViewIfNeeded()
        settings.tableView(UITableView(), didSelectRowAt: IndexPath(row: 0, section: 2))
        precondition(navigation.topViewController is DebugViewController)
        navigation.topViewController?.loadViewIfNeeded()
        print("STARTUP_CHECK PASS: 设置入口打开调试页")
        print("STARTUP_CHECK COMPLETE: 10 checks passed")
    }

    private static func verifyNotifications() async {
        let center = UNUserNotificationCenter.current()
        let service = DebugNotificationService()
        let receipts = Receipts()
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name("powerTestNotificationPresented"), object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                if let request = note.object as? UNNotificationRequest { receipts.ids.insert(request.identifier) }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
            let reminderState = UserDefaults.standard.dictionary(forKey: "lowBalanceReminder.lastSubmission.v1") as NSDictionary?
            let immediate = try await service.send(after: 0)
            let delayed = try await service.send(after: 2)
            let low = try await service.send(after: 0, lowBalance: true)
            for _ in 0..<50 {
                let delivered = Set(await center.deliveredNotifications().map { $0.request.identifier })
                if Set([immediate, delayed, low]).isSubset(of: receipts.ids.union(delivered)) { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let delivered = Set(await center.deliveredNotifications().map { $0.request.identifier })
            precondition(Set([immediate, delayed, low]).isSubset(of: receipts.ids.union(delivered)), "debug delivery missing")
            print("DEBUG_NOTIFICATION_CHECK PASS: 即时、延迟和低电量样式均实际投递")
            let toCancel = try await service.send(after: 10)
            let pending = await center.pendingNotificationRequests()
            precondition(pending.contains { $0.identifier == toCancel })
            let unrelated = Set(pending.filter { !$0.identifier.hasPrefix(DebugNotificationService.prefix) }.map(\.identifier))
            await service.clearTests()
            let remaining = Set(await center.pendingNotificationRequests().map(\.identifier))
            precondition(!remaining.contains(toCancel) && unrelated.isSubset(of: remaining))
            let afterClear = await center.deliveredNotifications()
            precondition(!afterClear.contains { $0.request.identifier.hasPrefix(DebugNotificationService.prefix) })
            precondition(reminderState == UserDefaults.standard.dictionary(forKey: "lowBalanceReminder.lastSubmission.v1") as NSDictionary?)
            print("DEBUG_NOTIFICATION_CHECK PASS: 10秒测试可取消、清理仅限测试、真实提醒状态未改变")
            print("DEBUG_NOTIFICATION_CHECK COMPLETE")
        } catch { preconditionFailure("DEBUG_NOTIFICATION_CHECK FAILED: \(error)") }
    }
}
#endif
