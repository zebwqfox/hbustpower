import Foundation
import UIKit

/// What the app reports so the developer can tell which versions are still in use and which devices break.
///
/// Everything here is either the app's own build information or the device's public model identifier. There is
/// no hardware identifier — no IDFA, no IDFV, no serial number. `installId` is a UUID this app generates on
/// first report, it is not derived from anything, and resetting it or switching reporting off makes the old one
/// unreachable. Nothing the school knows about the user — account, dorm, balance, usage — is included.
///
/// The wire format is shared with Android (`data/Telemetry.kt`) and the panel's `server/src/ingest.js`:
/// `osVersion` is the version string on both, `osApiLevel` is Android-only and omitted here.
struct TelemetryPayload: Equatable, Sendable {
    let installID: String
    var platform = "ios"
    var appVersionCode: Int = Bundle.main.versionCode
    var appVersionName: String = Bundle.main.versionName
    var osVersion: String
    var manufacturer = "Apple"
    /// The model identifier, e.g. "iPhone16,2" — the same string Apple's own crash reports use.
    var model: String
    var locale: String
    var channel: String

    init(
        installID: String,
        osVersion: String = UIDevice.current.systemVersion,
        model: String = TelemetryPayload.modelIdentifier,
        locale: String = Locale.current.identifier,
        channel: String = TelemetryPayload.defaultChannel
    ) {
        self.installID = installID
        self.osVersion = osVersion
        self.model = model
        self.locale = locale
        self.channel = channel
    }

    static var defaultChannel: String {
#if DEBUG
        "debug"
#else
        "release"
#endif
    }

    static var userAgent: String { "HBUSTPower/\(Bundle.main.versionName) (iOS)" }

    /// `UIDevice.model` only ever says "iPhone"; the useful identifier comes from `uname`.
    static var modelIdentifier: String {
        var info = utsname()
        uname(&info)
        let identifier = withUnsafeBytes(of: &info.machine) { raw in
            raw.prefix { $0 != 0 }.map { String(UnicodeScalar(UInt8($0))) }.joined()
        }
        return identifier.isEmpty ? "unknown" : identifier
    }

    func jsonData() -> Data {
        let body: [String: Any] = [
            "installId": installID,
            "platform": platform,
            "appVersionCode": appVersionCode,
            "appVersionName": appVersionName,
            "osVersion": osVersion,
            "manufacturer": manufacturer,
            "model": model,
            "locale": locale,
            "channel": channel,
        ]
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    /// What the settings screen shows, so nobody has to take the description on faith.
    func humanReadable() -> [(String, String)] {
        [
            ("安装标识", installID),
            ("应用版本", "\(appVersionName) (\(appVersionCode))"),
            ("系统版本", "iOS \(osVersion)"),
            ("设备型号", "\(manufacturer) \(model)"),
            ("语言", locale),
            ("渠道", channel),
        ]
    }
}

enum TelemetryEndpoint {
    static var reportURL: URL? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "TelemetryURL") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.hasPrefix("REPLACE_WITH"),
              let url = URL(string: value), url.scheme == "https", url.host != nil
        else { return nil }
        return url
    }

    static var isConfigured: Bool { reportURL != nil }
    static var host: String? { reportURL?.host }
}

protocol TelemetrySending: Sendable {
    /// True when the server accepted it; anything else just means "try again tomorrow".
    func send(_ payload: TelemetryPayload) async -> Bool
}

struct HTTPTelemetrySender: TelemetrySending {
    var url: URL?
    var session: URLSession

    init(url: URL? = TelemetryEndpoint.reportURL, session: URLSession? = nil) {
        self.url = url
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 10
            self.session = URLSession(configuration: configuration)
        }
    }

    func send(_ payload: TelemetryPayload) async -> Bool {
        guard let url else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(TelemetryPayload.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = payload.jsonData()

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

/// On unless switched off, then at most one report a day. Every decision lives in preferences, so turning it
/// off stops the next report rather than scheduling one more.
@MainActor
final class TelemetryStore {
    static let interval: TimeInterval = 24 * 60 * 60

    private enum Keys {
        static let enabled = "telemetry.enabled"
        static let installID = "telemetry.installId"
        static let lastSent = "telemetry.lastSent"
    }

    private let defaults: UserDefaults
    private let sender: TelemetrySending
    private let now: @Sendable () -> TimeInterval

    let isConfigured: Bool

    init(
        defaults: UserDefaults = .standard,
        sender: TelemetrySending = HTTPTelemetrySender(),
        isConfigured: Bool = TelemetryEndpoint.isConfigured,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.defaults = defaults
        self.sender = sender
        self.isConfigured = isConfigured
        self.now = now
    }

    /// On unless the user says otherwise. The switch is shown, already on, during first run before anything is
    /// sent, and again in settings — so "on by default" still means they were told.
    var isEnabled: Bool {
        get { defaults.object(forKey: Keys.enabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.enabled)
            // Turning it off forgets the identifier too, so switching back on starts a new one.
            if !newValue {
                defaults.removeObject(forKey: Keys.installID)
                defaults.removeObject(forKey: Keys.lastSent)
            }
        }
    }

    var lastSentAt: TimeInterval { defaults.double(forKey: Keys.lastSent) }

    /// Created lazily, so someone who switches this off before the first report never has one.
    func installID() -> String {
        if let existing = defaults.string(forKey: Keys.installID) { return existing }
        let fresh = UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: Keys.installID)
        return fresh
    }

    @discardableResult
    func resetInstallID() -> String {
        defaults.removeObject(forKey: Keys.installID)
        defaults.removeObject(forKey: Keys.lastSent)
        return installID()
    }

    func payload() -> TelemetryPayload { TelemetryPayload(installID: installID()) }

    /// The same content, for showing in settings, without creating an identifier as a side effect.
    func previewPayload() -> TelemetryPayload {
        TelemetryPayload(installID: defaults.string(forKey: Keys.installID) ?? "（开启后才会生成）")
    }

    func shouldSend(force: Bool = false) -> Bool {
        guard isConfigured, isEnabled else { return false }
        if force { return true }
        // Never sent means due now, rather than "due once the clock has been running for a day".
        if lastSentAt == 0 { return true }
        return now() - lastSentAt >= Self.interval
    }

    /// Returns true when something was actually sent and accepted.
    @discardableResult
    func report(force: Bool = false) async -> Bool {
        guard shouldSend(force: force) else { return false }
        guard await sender.send(payload()) else { return false }
        defaults.set(now(), forKey: Keys.lastSent)
        return true
    }
}
