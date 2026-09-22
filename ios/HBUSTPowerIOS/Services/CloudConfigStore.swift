import Foundation

/// Why a refresh happened, which decides whether a throttle applies and whether errors are shown.
enum CloudRefreshTrigger: Sendable {
    /// A cold start. Always checks: the switches exist to take a broken feature down quickly, and waiting a
    /// day to hear about it would defeat the point.
    case launch
    /// Returning from the background, which can happen dozens of times a day — hence a short floor.
    case foreground
    /// The user asked. Always checks and always reports what went wrong.
    case manual
}

/// What the UI needs to know after a refresh.
struct CloudConfigState: Equatable, Sendable {
    var config: CloudConfig = .empty
    var lastCheckedAt: TimeInterval = 0
    /// Set only after a manual check, so a failed silent check never interrupts anyone.
    var error: String?
    var isChecking = false

    var isEmpty: Bool { config == .empty && lastCheckedAt == 0 }
}

/// Keeps the last config on disk and decides when to ask for a new one: once a day on launch, or whenever the
/// user taps 检查更新. The cached copy is what the UI reads, so the app shows the same notice offline as it did
/// online and never waits on the network to draw a screen.
///
/// Nothing here is sent anywhere. It reads a file and remembers what the user dismissed.
@MainActor
final class CloudConfigStore {
    /// The shortest gap between two checks triggered by returning to the foreground.
    static let foregroundInterval: TimeInterval = 30 * 60
    private static let maxDismissed = 20

    private enum Keys {
        static let json = "cloudConfig.json"
        static let etag = "cloudConfig.etag"
        static let checkedAt = "cloudConfig.checkedAt"
        static let skipped = "cloudConfig.skippedVersion"
        static let dismissed = "cloudConfig.dismissedNotices"
    }

    private let defaults: UserDefaults
    private let fetcher: CloudConfigFetching
    private let trustedHosts: [String]
    private let currentVersionCode: Int
    private let now: @Sendable () -> TimeInterval

    let isConfigured: Bool

    init(
        defaults: UserDefaults = .standard,
        currentVersionCode: Int = Bundle.main.versionCode,
        fetcher: CloudConfigFetching = HTTPCloudConfigFetcher(),
        trustedHosts: [String] = CloudEndpoints.downloadHosts,
        isConfigured: Bool = CloudEndpoints.isConfigured,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.defaults = defaults
        self.currentVersionCode = currentVersionCode
        self.fetcher = fetcher
        self.trustedHosts = trustedHosts
        self.isConfigured = isConfigured
        self.now = now
    }

    /// The config as last fetched, or empty when nothing has ever been fetched.
    func cached() -> CloudConfig {
        guard let data = defaults.data(forKey: Keys.json) else { return .empty }
        return CloudConfig.parse(data, trustedDownloadHosts: trustedHosts)
    }

    var lastCheckedAt: TimeInterval { defaults.double(forKey: Keys.checkedAt) }

    func state(error: String? = nil) -> CloudConfigState {
        CloudConfigState(config: cached(), lastCheckedAt: lastCheckedAt, error: error)
    }

    func shouldCheck(_ trigger: CloudRefreshTrigger) -> Bool {
        guard isConfigured else { return false }
        switch trigger {
        case .launch, .manual:
            return true
        case .foreground:
            // Never checked means due now, rather than "due once the clock has been running a while".
            return lastCheckedAt == 0 || now() - lastCheckedAt >= Self.foregroundInterval
        }
    }

    /// Fetches unless the daily throttle says otherwise, stores what came back, and returns the state to show.
    func refresh(_ trigger: CloudRefreshTrigger) async -> CloudConfigState {
        guard shouldCheck(trigger) else { return state() }

        switch await fetcher.fetch(etag: defaults.string(forKey: Keys.etag)) {
        case let .fresh(data, etag):
            let parsed = CloudConfig.parse(data, trustedDownloadHosts: trustedHosts)
            if parsed == .empty && !data.isEmpty {
                // Keep the last good copy rather than replacing it with nothing.
                return state(error: trigger == .manual ? "更新信息格式不正确" : nil)
            }
            defaults.set(data, forKey: Keys.json)
            defaults.set(now(), forKey: Keys.checkedAt)
            if let etag, !etag.isEmpty {
                defaults.set(etag, forKey: Keys.etag)
            } else {
                defaults.removeObject(forKey: Keys.etag)
            }
            return state()

        case .notModified:
            defaults.set(now(), forKey: Keys.checkedAt)
            return state()

        case let .failed(reason):
            return state(error: trigger == .manual ? reason : nil)
        }
    }

    // MARK: - What the user has already dealt with

    /// The update to offer, unless the user said 跳过这个版本 for exactly that build.
    func pendingUpdate(_ config: CloudConfig? = nil) -> CloudConfig.Update? {
        let config = config ?? cached()
        guard let update = config.updateAvailable(currentVersionCode: currentVersionCode) else { return nil }
        if config.mustUpgrade(currentVersionCode: currentVersionCode) { return update }
        return update.versionCode == skippedVersionCode ? nil : update
    }

    private var skippedVersionCode: Int { defaults.integer(forKey: Keys.skipped) }

    func skip(_ update: CloudConfig.Update) {
        defaults.set(update.versionCode, forKey: Keys.skipped)
    }

    func activeNotice(_ config: CloudConfig? = nil) -> CloudConfig.Notice? {
        (config ?? cached()).activeNotice(now: now(), dismissedIDs: dismissedNoticeIDs)
    }

    func dismiss(_ notice: CloudConfig.Notice) {
        // Keep the list short: ids pile up otherwise, and an old id can never come back into view.
        let kept = ([notice.id] + dismissedNoticeIDs.sorted()).reduce(into: [String]()) { list, id in
            if !list.contains(id) { list.append(id) }
        }
        defaults.set(Array(kept.prefix(Self.maxDismissed)), forKey: Keys.dismissed)
    }

    private var dismissedNoticeIDs: Set<String> {
        Set(defaults.stringArray(forKey: Keys.dismissed) ?? [])
    }

    func isEnabled(_ flag: String) -> Bool { cached().isEnabled(flag) }

    var mustUpgrade: Bool { cached().mustUpgrade(currentVersionCode: currentVersionCode) }

    /// Forgets everything fetched, for the 清除本地数据 path.
    func clear() {
        [Keys.json, Keys.etag, Keys.checkedAt, Keys.skipped, Keys.dismissed].forEach(defaults.removeObject(forKey:))
    }
}

extension Bundle {
    /// `CFBundleVersion`, the iOS counterpart of Android's versionCode.
    var versionCode: Int {
        Int((object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "") ?? 0
    }

    var versionName: String {
        (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}
