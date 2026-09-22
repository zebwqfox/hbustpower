import Foundation
import UIKit
import UserNotifications

enum PushDestination: String, CaseIterable {
    case overview
    case usage
    case records
    case campusCard = "campus_card"
    case settings

    var tabIndex: Int {
        switch self {
        case .overview: 0
        case .usage: 1
        case .records: 2
        case .campusCard: 3
        case .settings: 4
        }
    }
}

struct RemotePushSnapshot: Equatable {
    let registrationStatus: String
    let serverStatus: String
    let tokenPreview: String
}

private struct PushRegistrationPayload: Encodable {
    let installationId: String
    let deviceToken: String
    let platform: String
    let bundleId: String
    let appVersion: String
    let buildNumber: String
    let pushEnvironment: String
    let locale: String
    let timeZone: String

    enum CodingKeys: String, CodingKey {
        case installationId = "installation_id"
        case deviceToken = "device_token"
        case platform
        case bundleId = "bundle_id"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case pushEnvironment = "push_environment"
        case locale
        case timeZone = "time_zone"
    }
}

/// Owns APNs registration and sends device tokens to the app's provider server.
/// The APNs provider key stays on the server and must never be bundled in the app.
@MainActor
final class RemotePushService {
    static let shared = RemotePushService()
    static let didChange = Notification.Name("remotePushServiceDidChange")
    static let didOpenNotification = Notification.Name("remotePushDidOpenNotification")

    private enum StorageKey {
        static let deviceToken = "apns.deviceToken"
        static let installationId = "push.installationId"
        static let lastUploadedFingerprint = "push.lastUploadedFingerprint"
    }

    private let session: URLSession
    private let defaults: UserDefaults
    private var uploadTask: Task<Void, Never>?
    private(set) var pendingDestination: PushDestination?
    private var registrationStatus = "尚未向 APNs 注册"
    private var serverStatus = "等待 APNs 设备令牌"

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
        if let token = KeychainStore.read(account: StorageKey.deviceToken), !token.isEmpty {
            registrationStatus = "已取得 APNs 设备令牌"
            serverStatus = Self.registrationEndpoint == nil ? "未配置服务端登记地址" : "等待核对服务端登记"
        }
    }

    var snapshot: RemotePushSnapshot {
        let token = KeychainStore.read(account: StorageKey.deviceToken) ?? ""
        return RemotePushSnapshot(
            registrationStatus: registrationStatus,
            serverStatus: serverStatus,
            tokenPreview: Self.preview(token: token)
        )
    }

    func registerIfAuthorized() async {
        await registerIfAuthorized(application: UIApplication.shared)
    }

    func registerIfAuthorized(application: UIApplication) async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard [.authorized, .provisional, .ephemeral].contains(status) else {
            registrationStatus = status == .denied ? "通知权限已关闭" : "等待用户允许通知"
            publishChange()
            return
        }
        registrationStatus = "正在向 APNs 注册"
        publishChange()
        application.registerForRemoteNotifications()
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else {
            registrationStatus = "APNs 返回了空设备令牌"
            publishChange()
            return
        }
        do {
            try KeychainStore.save(token, account: StorageKey.deviceToken)
        } catch {
            registrationStatus = "已取得令牌，但未能安全保存"
            PowerDiagnostics.shared.record("远程推送：APNs 令牌未能写入钥匙串")
            publishChange()
            upload(token: token)
            return
        }
        registrationStatus = "已取得 APNs 设备令牌"
        PowerDiagnostics.shared.record("远程推送：已取得 APNs 设备令牌")
        publishChange()
        upload(token: token)
    }

    func didFailToRegister(_ error: Error) {
        let value = error as NSError
        registrationStatus = "APNs 注册失败（错误代码 \(value.code)）"
        PowerDiagnostics.shared.record("远程推送：APNs 注册失败（错误代码 \(value.code)）")
        publishChange()
    }

    func retry() async {
        await retry(application: UIApplication.shared)
    }

    func retry(application: UIApplication) async {
        await registerIfAuthorized(application: application)
        if let token = KeychainStore.read(account: StorageKey.deviceToken), !token.isEmpty {
            upload(token: token, force: true)
        }
    }

    func handle(userInfo: [AnyHashable: Any]) {
        guard let rawDestination = userInfo["destination"] as? String,
              let destination = PushDestination(rawValue: rawDestination) else {
            PowerDiagnostics.shared.record("远程推送：用户已打开通知")
            return
        }
        pendingDestination = destination
        PowerDiagnostics.shared.record("远程推送：打开目标页面 \(rawDestination)")
        NotificationCenter.default.post(name: Self.didOpenNotification, object: self)
    }

    func consumePendingDestination() -> PushDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    private func upload(token: String, force: Bool = false) {
        guard let endpoint = Self.registrationEndpoint else {
            serverStatus = "未配置服务端登记地址"
            PowerDiagnostics.shared.record("远程推送：已取得令牌，等待配置 HTTPS 登记地址")
            publishChange()
            return
        }
        let fingerprint = Self.registrationFingerprint(token: token, endpoint: endpoint)
        if !force, defaults.string(forKey: StorageKey.lastUploadedFingerprint) == fingerprint {
            serverStatus = "设备令牌已登记"
            publishChange()
            return
        }

        uploadTask?.cancel()
        serverStatus = "正在登记设备令牌"
        publishChange()
        uploadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let payload = PushRegistrationPayload(
                    installationId: try self.installationId(),
                    deviceToken: token,
                    platform: "ios",
                    bundleId: Bundle.main.bundleIdentifier ?? "unknown",
                    appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                    buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                    pushEnvironment: Self.pushEnvironment,
                    locale: Locale.current.identifier,
                    timeZone: TimeZone.current.identifier
                )
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 15
                request.httpBody = try JSONEncoder().encode(payload)
                let (_, response) = try await session.data(for: request)
                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw PushRegistrationError.serverRejected((response as? HTTPURLResponse)?.statusCode)
                }
                defaults.set(fingerprint, forKey: StorageKey.lastUploadedFingerprint)
                serverStatus = "设备令牌已登记"
                PowerDiagnostics.shared.record("远程推送：设备令牌已在服务端登记")
            } catch is CancellationError {
                return
            } catch {
                serverStatus = "登记失败；下次启动会重试"
                PowerDiagnostics.shared.record("远程推送：服务端登记失败（\(Self.safeErrorCode(error))）")
            }
            publishChange()
        }
    }

    private func installationId() throws -> String {
        if let existing = KeychainStore.read(account: StorageKey.installationId), !existing.isEmpty { return existing }
        let value = UUID().uuidString.lowercased()
        try KeychainStore.save(value, account: StorageKey.installationId)
        return value
    }

    private func publishChange() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private static var registrationEndpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "HBUSTPushRegistrationEndpoint") as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: value), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }

    private static var pushEnvironment: String {
        Bundle.main.object(forInfoDictionaryKey: "HBUSTPushEnvironment") as? String ?? "unknown"
    }

    private static func preview(token: String) -> String {
        guard token.count >= 12 else { return token.isEmpty ? "尚未取得" : "已取得（已隐藏）" }
        return String(token.prefix(8)) + "…" + String(token.suffix(4))
    }

    private static func registrationFingerprint(token: String, endpoint: URL) -> String {
        [
            token,
            endpoint.absoluteString,
            Bundle.main.bundleIdentifier ?? "unknown",
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            pushEnvironment
        ].joined(separator: "|")
    }

    private static func safeErrorCode(_ error: Error) -> String {
        if let error = error as? PushRegistrationError { return error.description }
        let value = error as NSError
        return "\(value.domain == NSURLErrorDomain ? "网络" : "系统") \(value.code)"
    }
}

private enum PushRegistrationError: Error {
    case serverRejected(Int?)
    var description: String {
        switch self {
        case let .serverRejected(code): "HTTP \(code.map(String.init) ?? "未知")"
        }
    }
}
