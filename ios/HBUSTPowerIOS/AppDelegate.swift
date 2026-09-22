import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        configureNotificationCategories()
        Task { @MainActor in
            await RemotePushService.shared.registerIfAuthorized(application: application)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        RemotePushService.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        RemotePushService.shared.didFailToRegister(error)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let isTest = notification.request.identifier.hasPrefix(DebugNotificationService.prefix)
        let isRemote = notification.request.trigger is UNPushNotificationTrigger
        Task { @MainActor in
            let message = isRemote ? "远程推送已由前台代理收到" : (isTest ? "测试通知已由前台代理收到" : "低电量通知已由前台代理收到")
            PowerDiagnostics.shared.record(message)
        }
#if DEBUG
        NotificationCenter.default.post(name: Notification.Name("powerTestNotificationPresented"), object: notification.request)
#endif
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        if request.trigger is UNPushNotificationTrigger || request.content.userInfo["destination"] != nil {
            RemotePushService.shared.handle(userInfo: request.content.userInfo)
        }
        completionHandler()
    }

    private func configureNotificationCategories() {
        let viewAction = UNNotificationAction(identifier: "OPEN_APP", title: "查看", options: [.foreground])
        let categories = [
            UNNotificationCategory(identifier: "POWER_ALERT", actions: [viewAction], intentIdentifiers: []),
            UNNotificationCategory(identifier: "CAMPUS_NOTICE", actions: [viewAction], intentIdentifiers: []),
            UNNotificationCategory(identifier: "APP_UPDATE", actions: [viewAction], intentIdentifiers: [])
        ]
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }
}
