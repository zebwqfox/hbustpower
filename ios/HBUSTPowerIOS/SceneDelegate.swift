import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let model = AppModel()
    private var hasStarted = false
    private var themeObserver: NSObjectProtocol?
    private var pushObserver: NSObjectProtocol?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        if let response = connectionOptions.notificationResponse,
           response.notification.request.trigger is UNPushNotificationTrigger || response.notification.request.content.userInfo["destination"] != nil {
            RemotePushService.shared.handle(userInfo: response.notification.request.content.userInfo)
        }
        let window = UIWindow(windowScene: windowScene)
        let root = RootTabBarController(model: model)
#if DEBUG
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--preview-tab=") }),
           let index = Int(argument.replacingOccurrences(of: "--preview-tab=", with: "")) {
            root.selectedIndex = index
        }
#endif
        window.tintColor = PowerTheme.accent
        self.window = window
        var needsIntroduction = !UserDefaults.standard.bool(forKey: FirstRunFlow.completedKey)
#if DEBUG
        if CommandLine.arguments.contains("--ui-preview") || CommandLine.arguments.contains("--welcome-preview") || CommandLine.arguments.contains("--startup-preview") { needsIntroduction = false }
        if CommandLine.arguments.contains("--onboarding-preview") { needsIntroduction = true }
#endif
        if needsIntroduction {
            let flow: FirstRunFlow
#if DEBUG
            if CommandLine.arguments.contains("--onboarding-preview") {
                flow = FirstRunFlow(defaults: UserDefaults(suiteName: "firstRun.preview")!)
            } else { flow = FirstRunFlow() }
#else
            flow = FirstRunFlow()
#endif
            window.rootViewController = FirstRunViewController(flow: flow) { [weak self, weak window] in
                guard let self, let window, !self.hasStarted else { return }
                UIView.transition(with: window, duration: UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.3, options: .transitionCrossDissolve) {
                    window.rootViewController = root
                }
                self.finishStartup(root: root)
            }
            window.makeKeyAndVisible()
        } else {
            window.rootViewController = root
            window.makeKeyAndVisible()
            finishStartup(root: root)
        }
#if DEBUG
        FirstRunVerification.run()
#endif
    }

    deinit {
        if let themeObserver { NotificationCenter.default.removeObserver(themeObserver) }
        if let pushObserver { NotificationCenter.default.removeObserver(pushObserver) }
    }

    /// Colours are baked into views as they are drawn, so a new theme needs a fresh interface.
    private func observeTheme() {
        guard themeObserver == nil else { return }
        themeObserver = NotificationCenter.default.addObserver(forName: PowerThemeStore.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.window else { return }
                let selected = (window.rootViewController as? RootTabBarController)?.selectedIndex ?? 0
                let root = RootTabBarController(model: self.model)
                root.loadViewIfNeeded()
                root.selectedIndex = selected
                window.tintColor = PowerTheme.accent
                UIView.transition(with: window, duration: UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.35, options: .transitionCrossDissolve) {
                    window.rootViewController = root
                }
                if let settings = (root.viewControllers?[4] as? UINavigationController) {
                    settings.pushViewController(ThemePickerViewController(), animated: false)
                }
            }
        }
    }

    private func finishStartup(root: RootTabBarController) {
        guard !hasStarted else { return }
        hasStarted = true
        observeTheme()
        observePushNavigation()
        model.start()
        applyPendingPush(to: root)
#if DEBUG
        if CommandLine.arguments.contains("--preview-debug"),
           let navigation = root.viewControllers?[4] as? UINavigationController {
            root.selectedIndex = 4
            navigation.pushViewController(DebugViewController(model: model), animated: false)
        }
        if CommandLine.arguments.contains("--preview-widgets"),
           let navigation = root.viewControllers?[4] as? UINavigationController {
            root.selectedIndex = 4
            navigation.pushViewController(WidgetPreviewViewController(), animated: false)
        }
        if CommandLine.arguments.contains("--preview-changelog"),
           let navigation = root.viewControllers?[4] as? UINavigationController {
            root.selectedIndex = 4
            navigation.pushViewController(ChangelogViewController(), animated: false)
        }
        // Mimics the vertical bar on iPhone Duo's outer display: content must stay clear of an uneven trailing inset.
        if CommandLine.arguments.contains("--simulate-vertical-bar") {
            root.viewControllers?.forEach { $0.additionalSafeAreaInsets.right = 76 }
            let bar = UIView()
            bar.backgroundColor = UIColor.systemRed.withAlphaComponent(0.25)
            bar.isUserInteractionEnabled = false
            bar.frame = CGRect(x: root.view.bounds.width - 76 - root.view.safeAreaInsets.right, y: 0, width: 76, height: root.view.bounds.height)
            bar.autoresizingMask = [.flexibleLeftMargin, .flexibleHeight]
            root.view.addSubview(bar)
        }
        if CommandLine.arguments.contains("--preview-about"),
           let navigation = root.viewControllers?[4] as? UINavigationController {
            root.selectedIndex = 4
            navigation.pushViewController(AboutViewController(model: model), animated: false)
        }
        if CommandLine.arguments.contains("--native-login-preview") || CommandLine.arguments.contains("--live-login-check") {
            root.present(UINavigationController(rootViewController: AuthenticationViewController(model: model)), animated: false)
        }
        AuthenticationLayoutVerification.run(root: root)
        StartupDebugVerification.run()
        DesignVerification.run(root: root)
        LowBalanceVerification.run()
#endif
    }

    private func observePushNavigation() {
        guard pushObserver == nil else { return }
        pushObserver = NotificationCenter.default.addObserver(forName: RemotePushService.didOpenNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let root = self.window?.rootViewController as? RootTabBarController else { return }
                self.applyPendingPush(to: root)
            }
        }
    }

    private func applyPendingPush(to root: RootTabBarController) {
        guard let destination = RemotePushService.shared.consumePendingDestination() else { return }
        root.selectedIndex = destination.tabIndex
        if let navigation = root.viewControllers?[destination.tabIndex] as? UINavigationController {
            navigation.popToRootViewController(animated: false)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard hasStarted else { return }
        model.refresh()
    }
}
