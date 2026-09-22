#if DEBUG
import UIKit
import UserNotifications

@MainActor
private final class FirstRunTestCenter: PowerNotificationCenter {
    var status: UNAuthorizationStatus = .notDetermined
    var grant = true
    var fails = false
    var requests = 0
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        requests += 1
        try await Task.sleep(for: .milliseconds(20))
        if fails { throw NSError(domain: "test", code: 1) }
        status = grant ? .authorized : .denied
        return grant
    }
    func submit(_ request: UNNotificationRequest) async throws {}
}

@MainActor
enum FirstRunVerification {
    static func run() {
        guard CommandLine.arguments.contains("--verify-first-run") else { return }
        Task {
            let suite = "firstRun.test." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let center = FirstRunTestCenter()
            let flow = FirstRunFlow(defaults: defaults, center: center)
            precondition(flow.step == .permission && !defaults.bool(forKey: FirstRunFlow.completedKey))
            flow.finish()
            precondition(flow.step == .permission)
            async let first: Void = flow.requestPermission()
            async let second: Void = flow.requestPermission()
            _ = await (first, second)
            precondition(center.requests == 1 && flow.step == .introduction && !flow.busy)
            flow.back(); await flow.requestPermission()
            precondition(center.requests == 1 && flow.step == .introduction)
            flow.finish(); flow.finish()
            precondition(defaults.bool(forKey: FirstRunFlow.completedKey) && flow.step == .finished)
            print("FIRST_RUN_CHECK PASS: permission first, no premature completion, double taps, back, persistent completion")
            let denied = FirstRunTestCenter(); denied.grant = false
            let deniedFlow = FirstRunFlow(defaults: defaults, center: denied)
            await deniedFlow.requestPermission()
            precondition(deniedFlow.step == .permissionDenied)
            denied.status = .authorized
            await deniedFlow.refreshAuthorization()
            precondition(deniedFlow.step == .introduction)
            let failed = FirstRunTestCenter(); failed.fails = true
            let retry = FirstRunFlow(defaults: defaults, center: failed)
            await retry.requestPermission()
            precondition(retry.error != nil && !retry.busy && retry.step == .permission)
            failed.fails = false; await retry.requestPermission()
            precondition(retry.step == .introduction && retry.error == nil)
            print("FIRST_RUN_CHECK PASS: denial, return from Settings, failure and retry")
            let skipped = FirstRunTestCenter()
            let skip = FirstRunFlow(defaults: defaults, center: skipped)
            skip.continueWithoutPermission()
            precondition(skip.step == .introduction && skipped.requests == 0 && defaults.bool(forKey: "notificationPermission.deferred"))
            let reminder = LowBalanceReminder(defaults: defaults, center: skipped)
            await reminder.evaluate(balance: 5, threshold: 20, room: "test")
            precondition(skipped.requests == 0)
            print("FIRST_RUN_CHECK PASS: skipped permission is respected by low-balance reminder")
            let screenFlow = FirstRunFlow(defaults: defaults, center: FirstRunTestCenter())
            screenFlow.continueWithoutPermission()
            var completions = 0
            let screen = FirstRunViewController(flow: screenFlow) { completions += 1 }
            screen.loadViewIfNeeded()
            @MainActor func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
            let start = descendants(screen.view).compactMap { $0 as? UIButton }.first { $0.configuration?.title == "开始使用" }!
            start.sendActions(for: .touchUpInside); start.sendActions(for: .touchUpInside)
            precondition(completions == 1)
            print("FIRST_RUN_CHECK PASS: native completion action delivered exactly once")
            print("FIRST_RUN_CHECK COMPLETE")
        }
    }
}
#endif
