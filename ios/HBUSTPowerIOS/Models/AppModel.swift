import UIKit
import WebKit
import WidgetKit

@MainActor
final class AppModel {
    enum Status: Equatable { case idle, loading, ready, authenticationRequired, error(String) }

    private enum Keys {
        static let redirect = "electricityRedirect"
        static let threshold = "lowBalanceThreshold"
    }

    private let defaults: UserDefaults
    private let service = ElectricityService()
    private let lowBalanceReminder: LowBalanceReminder
    private let cloud: CloudConfigStore
    private let telemetry: TelemetryStore
    /// Nothing reaches the network before `start()`: the first-run screen runs ahead of it and its toggle
    /// must be answerable without anything having been sent yet.
    private var hasStarted = false
    private var cloudTask: Task<Void, Never>?
    private var telemetryTask: Task<Void, Never>?
    private var reminderTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var refreshStartedAt: Date?
    private(set) var lastRefreshDuration: TimeInterval?
    private(set) var lastRefreshResult = "尚未刷新"
    var hasSavedLogin: Bool { KeychainStore.read(account: Keys.redirect) != nil }
    var reminderDiagnostic: String { lowBalanceReminder.diagnosticStatus }


    init(
        defaults: UserDefaults = .standard,
        reminder: LowBalanceReminder? = nil,
        cloud: CloudConfigStore? = nil,
        telemetry: TelemetryStore? = nil
    ) {
        self.defaults = defaults
        self.lowBalanceReminder = reminder ?? LowBalanceReminder(defaults: defaults)
        self.cloud = cloud ?? CloudConfigStore(defaults: defaults)
        self.telemetry = telemetry ?? TelemetryStore(defaults: defaults)
        // The cached copy only; the first request waits for start().
        publishCloud(self.cloud.state())
        telemetryEnabled = self.telemetry.isEnabled
    }

    // MARK: - Cloud config

    /// Version notice, announcement and feature switches, as last fetched. Empty until the first check.
    private(set) var cloudState = CloudConfigState()
    private(set) var pendingUpdate: CloudConfig.Update?
    private(set) var notice: CloudConfig.Notice?

    /// False when the build has no config address or the published config hides version-update UI.
    var isUpdateCheckAvailable: Bool {
        cloud.isConfigured && cloudState.config.isEnabled(CloudConfig.flagUpdateCheck)
    }
    var cloudConfigHost: String? { CloudEndpoints.configHost }

    /// True when this build is older than the oldest one the school pages still work with.
    var mustUpgrade: Bool {
        isUpdateCheckAvailable && cloudState.config.mustUpgrade(currentVersionCode: Bundle.main.versionCode)
    }

    /// Feature switches fail open, so an unreachable config never takes a feature away.
    func isFeatureEnabled(_ flag: String) -> Bool { cloudState.config.isEnabled(flag) }

    /// Reads the version/notice file from the developer's own site. A launch always checks; foreground checks
    /// are throttled to 30 minutes; a manual check always asks and reports what went wrong. Nothing is sent: it
    /// is a plain GET with no cookies and only a timestamp cache-busting parameter.
    func checkForUpdates(_ trigger: CloudRefreshTrigger) {
        guard hasStarted, cloud.isConfigured, cloudTask == nil else { return }
        guard cloud.shouldCheck(trigger) else {
            if trigger == .manual { publishCloud(cloud.state()) }
            return
        }
        cloudState.isChecking = true
        cloudState.error = nil
        notifyChange()
        cloudTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.cloud.refresh(trigger)
            self.cloudTask = nil
            self.publishCloud(result)
            let summary = result.error
                ?? self.cloud.pendingUpdate(result.config).map { "发现 " + $0.versionName }
                ?? "已是最新"
            PowerDiagnostics.shared.record("检查更新：" + summary)
        }
    }

    /// Stops offering this particular version; a later one, or a required upgrade, still shows.
    func skipUpdate() {
        if let pendingUpdate { cloud.skip(pendingUpdate) }
        pendingUpdate = cloud.pendingUpdate(cloudState.config)
        notifyChange()
    }

    func dismissNotice() {
        if let notice { cloud.dismiss(notice) }
        notice = cloud.activeNotice(cloudState.config)
        notifyChange()
    }

    private func publishCloud(_ state: CloudConfigState) {
        cloudState = state
        cloudState.isChecking = false
        pendingUpdate = state.config.isEnabled(CloudConfig.flagUpdateCheck)
            ? cloud.pendingUpdate(state.config)
            : nil
        notice = cloud.activeNotice(state.config)
        notifyChange()
    }

    // MARK: - Anonymous usage reporting

    /// On unless switched off, and hidden entirely when not configured.
    private(set) var telemetryEnabled = true
    var isTelemetryAvailable: Bool { telemetry.isConfigured }
    var telemetryHost: String? { TelemetryEndpoint.host }
    var telemetryLastSentAt: TimeInterval { telemetry.lastSentAt }

    /// Exactly what a report would contain, so settings can show it instead of describing it.
    func telemetryPreview() -> [(String, String)] { telemetry.previewPayload().humanReadable() }

    /// Sends the anonymous version/device report, at most once a day and only when switched on. Failures are
    /// silent: this exists for the developer's benefit, never the user's.
    func reportUsage(force: Bool = false) {
        guard hasStarted, telemetry.shouldSend(force: force), telemetryTask == nil else { return }
        telemetryTask = Task { [weak self] in
            guard let self else { return }
            let sent = await self.telemetry.report(force: force)
            self.telemetryTask = nil
            if sent { PowerDiagnostics.shared.record("已发送匿名使用统计") }
        }
    }

    /// The first-run toggle and the settings switch both land here.
    func setTelemetryEnabled(_ enabled: Bool) {
        telemetry.isEnabled = enabled
        telemetryEnabled = telemetry.isEnabled
        PowerDiagnostics.shared.record(enabled ? "已开启匿名使用统计" : "已关闭匿名使用统计，并清除本机安装标识")
        if enabled { reportUsage(force: true) }
        notifyChange()
    }

    /// Gives this install a new random identifier; the old one can no longer be linked to this device.
    func resetTelemetryID() {
        telemetry.resetInstallID()
        PowerDiagnostics.shared.record("已重置匿名安装标识")
        notifyChange()
    }

    private(set) var snapshot: ElectricitySnapshot?
    private(set) var status: Status = .idle
    var lowBalanceThreshold: Double {
        get { defaults.object(forKey: Keys.threshold) as? Double ?? 20 }
        set {
            guard newValue.isFinite, newValue > 0 else { return }
            defaults.set(newValue, forKey: Keys.threshold)
            notifyChange()
        }
    }

    var statusText: String {
        switch status {
        case .idle: "尚未更新"
        case .loading: "正在连接学校电费系统…"
        case .ready: "数据已更新"
        case .authenticationRequired: "需要登录智慧湖科"
        case let .error(message): message
        }
    }

    func start() {
#if DEBUG
        // Lets the notice banner be inspected without publishing anything real.
        if let raw = CommandLine.arguments.first(where: { $0.hasPrefix("--preview-notice=") })?
            .dropFirst("--preview-notice=".count) {
            var notice = CloudConfig.Notice(id: "preview", body: String(raw))
            notice.title = "学校系统维护"
            notice.level = .warning
            var config = CloudConfig()
            config.notice = notice
            publishCloud(CloudConfigState(config: config))
        }
        if CommandLine.arguments.contains("--ui-preview") {
            applyPreviewSnapshot()
            return
        }
#endif
        hasStarted = true
        refresh()
        checkForUpdates(.launch)
        reportUsage()
    }

    func refresh() {
#if DEBUG
        if CommandLine.arguments.contains("--startup-preview") {
            status = .loading
            notifyChange()
            return
        }
        if CommandLine.arguments.contains("--ui-preview") {
            // Lets the pull-to-refresh animation be seen offline.
            if CommandLine.arguments.contains("--slow-refresh-preview"), snapshot != nil {
                status = .loading
                notifyChange()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    self.applyPreviewSnapshot()
                }
                return
            }
            applyPreviewSnapshot()
            return
        }
        if CommandLine.arguments.contains("--welcome-preview") {
            snapshot = nil
            status = .authenticationRequired
            notifyChange()
            return
        }
#endif
        guard status != .loading else { return }
        beginRefresh()
        status = .loading
        notifyChange()
        refreshTask?.cancel()
        refreshTask = Task {
            do {
                let value: ElectricitySnapshot
                do { value = try await service.fetchCurrentSession() }
                catch ElectricityError.authenticationRequired {
                    PowerDiagnostics.shared.record("当前会话失效，尝试恢复本机登录")
                    value = try await recoverSavedSession()
                }
                guard !Task.isCancelled else { return }
                apply(value)
            } catch ElectricityError.authenticationRequired {
                guard !Task.isCancelled else { return }
                finishRefresh("需要登录")
                status = .authenticationRequired
                notifyChange()
            } catch ElectricityError.invalidRedirect {
                guard !Task.isCancelled else { return }
                finishRefresh("授权已失效")
                status = .authenticationRequired
                notifyChange()
            } catch {
                guard !Task.isCancelled else { return }
                finishRefresh(PowerDiagnostics.errorSummary(error))
                status = .error(error.localizedDescription)
                notifyChange()
            }
        }
    }

    func completeAuthentication(with url: URL) {
        guard ElectricityService.isValidElectricityRedirect(url) else { return }
        beginRefresh()
        status = .loading
        notifyChange()
        refreshTask?.cancel()
        refreshTask = Task {
            do {
                // Remembering the authorization only saves a login next time; failing to store it must not stop this load.
                do {
                    try KeychainStore.save(url.absoluteString, account: Keys.redirect)
                } catch {
                    PowerDiagnostics.shared.record("登录信息未能保存到钥匙串（\(PowerDiagnostics.errorSummary(error))），下次打开需要重新登录")
                }
                let value = try await service.establishSession(with: url)
                guard !Task.isCancelled else { return }
                apply(value)
            } catch {
                guard !Task.isCancelled else { return }
                finishRefresh(PowerDiagnostics.errorSummary(error))
                status = .error(error.localizedDescription)
                notifyChange()
            }
        }
    }

    func clearLogin() {
        refreshTask?.cancel()
        refreshStartedAt = nil
        PowerDiagnostics.shared.record("已清除本机登录")
        reminderTask?.cancel()
        lowBalanceReminder.reset()
        KeychainStore.delete(account: Keys.redirect)
        PowerWidgetStore.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: PowerWidgetStore.widgetKind)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
        snapshot = nil
        status = .authenticationRequired
        notifyChange()
    }

    private func recoverSavedSession() async throws -> ElectricitySnapshot {
        guard let raw = KeychainStore.read(account: Keys.redirect), let url = URL(string: raw) else {
            throw ElectricityError.authenticationRequired
        }
        return try await service.establishSession(with: url)
    }

    private func beginRefresh() {
        refreshStartedAt = Date()
        lastRefreshResult = "正在刷新"
        PowerDiagnostics.shared.record("开始读取电量")
    }

    private func finishRefresh(_ result: String) {
        lastRefreshDuration = refreshStartedAt.map { Date().timeIntervalSince($0) }
        refreshStartedAt = nil
        lastRefreshResult = result
        PowerDiagnostics.shared.record("读取电量：" + result)
    }

    private func apply(_ newSnapshot: ElectricitySnapshot) {
        finishRefresh("成功")
        snapshot = newSnapshot
        status = .ready
        notifyChange()
        publishToWidgets(newSnapshot)
        let threshold = lowBalanceThreshold
        reminderTask = Task {
            await lowBalanceReminder.evaluate(balance: newSnapshot.purchasedKWh, threshold: threshold, room: newSnapshot.room)
        }
    }

    /// Hands the home-screen widgets the few numbers they show. Without the App Group entitlement this is a no-op.
    private func publishToWidgets(_ snapshot: ElectricitySnapshot) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: snapshot.usageRecords) { calendar.startOfDay(for: $0.date) }
        let days = grouped.keys.sorted().suffix(7).map { day in
            let records = grouped[day] ?? []
            return PowerWidgetSnapshot.Day(date: day,
                                           lighting: records.filter { $0.kind == "照明" }.map(\.kWh).reduce(0, +),
                                           airConditioning: records.filter { $0.kind == "空调" }.map(\.kWh).reduce(0, +))
        }
        PowerWidgetStore.save(PowerWidgetSnapshot(
            room: snapshot.room,
            balanceKWh: snapshot.purchasedKWh,
            predictedDays: snapshot.predictedDays,
            dailyLighting: snapshot.recentAverage(kind: "照明"),
            dailyAirConditioning: snapshot.recentAverage(kind: "空调"),
            days: days,
            isLow: snapshot.purchasedKWh < lowBalanceThreshold,
            updatedAt: snapshot.fetchedAt
        ), theme: PowerThemeStore.shared.style)
        WidgetCenter.shared.reloadTimelines(ofKind: PowerWidgetStore.widgetKind)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .powerModelDidChange, object: self)
    }

#if DEBUG
    func setVerificationState(_ status: Status, keepSnapshot: Bool = false) {
        if !keepSnapshot { snapshot = nil }
        self.status = status
        notifyChange()
    }

    func applyLowBalanceTestReading(_ balance: Double, room: String = "测试宿舍") async {
        apply(ElectricitySnapshot(room: room, purchasedKWh: balance, subsidyKWh: nil, unitPrice: nil,
                                  meters: [], usageRecords: [], rechargeRecords: [], fetchedAt: Date()))
        await reminderTask?.value
    }

    private func applyPreviewSnapshot() {
        let calendar = Calendar.current
        let records = (0..<14).flatMap { offset -> [UsageRecord] in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return [
                UsageRecord(date: date, kWh: 4.8 + Double(offset % 3) * 0.62, meterName: "东10-625照明"),
                UsageRecord(date: date, kWh: 20.2 + Double(offset % 4) * 1.08, meterName: "东10-625空调")
            ]
        }
        snapshot = ElectricitySnapshot(
            room: "东10-625",
            purchasedKWh: CommandLine.arguments.contains("--low-balance-preview") ? 12.50 : 194.67,
            subsidyKWh: 0,
            unitPrice: 0.57,
            meters: [
                MeterStatus(name: "东10-625照明", powerStatus: "正常用电", communicationStatus: "通讯正常"),
                MeterStatus(name: "东10-625空调", powerStatus: "正常用电", communicationStatus: "通讯正常")
            ],
            usageRecords: records,
            rechargeRecords: [
                RechargeRecord(
                    date: Date(),
                    amountText: "100.00元",
                    kWhText: "175.44度",
                    type: "一卡通充值",
                    meterName: "东10-625",
                    studentNumber: "2026123456"
                )
            ],
            fetchedAt: Date()
        )
        status = .ready
        notifyChange()
        if let snapshot { publishToWidgets(snapshot) }
    }
#endif
}
