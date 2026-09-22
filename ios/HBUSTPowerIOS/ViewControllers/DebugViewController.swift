import UIKit
import UserNotifications

final class DebugViewController: ModelViewController, UITableViewDataSource, UITableViewDelegate {
    private struct Row {
        let title: String
        let detail: String
        var action: (() -> Void)? = nil
    }
    private struct Section {
        let title: String
        let footer: String?
        let rows: [Row]
    }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let notifications = DebugNotificationService()
    private var settings: UNNotificationSettings?
    private var pendingCount = 0
    private var deliveredCount = 0
    private var busy = false
    private var result = "选择一项测试，结果会显示在这里。"
    private var sections: [Section] = []
    private var observers: [NSObjectProtocol] = []
    private var reloadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "调试与诊断"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(copyReport))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "复制诊断报告"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.accessibilityIdentifier = "debug.table"
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        connectScrolling(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refresh
        for name in [UIApplication.didBecomeActiveNotification, PowerDiagnostics.didChange, RemotePushService.didChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reloadDiagnostics() }
            })
        }
        rebuildSections()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        reloadTask?.cancel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDiagnostics()
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        rebuildSections()
    }

    @objc private func refreshPulled() { reloadDiagnostics() }

    private func reloadDiagnostics() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            guard let self, !Task.isCancelled else { return }
            self.settings = settings
            self.pendingCount = pending.filter { $0.identifier.hasPrefix(DebugNotificationService.prefix) }.count
            self.deliveredCount = delivered.filter { $0.request.identifier.hasPrefix(DebugNotificationService.prefix) }.count
            self.tableView.refreshControl?.endRefreshing()
            self.rebuildSections()
        }
    }

    /// The real-size widget preview only exists in debug builds.
    private var widgetPreviewRows: [Row] {
#if DEBUG
        [Row(title: "预览小组件", detail: "按真实尺寸查看三套主题的小组件", action: { [weak self] in
            guard let self else { return }
            self.navigationController?.pushViewController(WidgetPreviewViewController(), animated: true)
        })]
#else
        []
#endif
    }

    private func rebuildSections() {
        let snapshot = model.snapshot
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let status: String
        switch model.status {
        case .idle: status = "等待启动"
        case .loading: status = "正在连接"
        case .ready: status = "已取得电量"
        case .authenticationRequired: status = "需要登录"
        case .error: status = "连接失败（详见刷新结果）"
        }
        let cookies = HTTPCookieStorage.shared.cookies?.filter {
            $0.domain == "hbust.edu.cn" || $0.domain.hasSuffix(".hbust.edu.cn")
        }.count ?? 0
        let remotePush = RemotePushService.shared.snapshot
        sections = [
            Section(title: "通知状态", footer: "临时授权通常静默投递。横幅与声音还受专注模式、静音和通知摘要影响。下拉可更新状态。", rows: [
                Row(title: "系统权限", detail: settings.map { Self.authorizationText($0.authorizationStatus) } ?? "读取中…"),
                Row(title: "横幅 · 声音 · 锁屏", detail: settings.map { "\(Self.settingText($0.alertSetting)) · \(Self.settingText($0.soundSetting)) · \(Self.settingText($0.lockScreenSetting))" } ?? "读取中…"),
                Row(title: "测试通知", detail: "待发送 \(pendingCount) 条 · 通知中心保留 \(deliveredCount) 条"),
                Row(title: "申请通知权限", detail: "尚未选择时显示系统授权弹窗", action: { [weak self] in self?.requestPermission() }),
                Row(title: "打开系统通知设置", detail: "修改横幅、声音和锁屏显示", action: {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                })
            ]),
            Section(title: "通知测试", footer: "低电量样式使用虚构的 12.50 度，仅测试通知显示。实际提醒仍在电量刷新后判断，测试不会修改真实电量或去重记录。", rows: [
                Row(title: "立即发送", detail: "在应用前台检查通知", action: { [weak self] in self?.sendTest(after: 0) }),
                Row(title: "10 秒后发送", detail: "点击后切到后台或锁屏", action: { [weak self] in self?.sendTest(after: 10) }),
                Row(title: "测试低电量样式", detail: "模拟低于 20 度的提醒文案", action: { [weak self] in self?.sendTest(after: 0, lowBalance: true) }),
                Row(title: "清除测试通知", detail: "取消待发送测试，并移除已投递测试", action: { [weak self] in
                    self?.perform { [weak self] in
                        guard let self else { return }
                        await self.notifications.clearTests()
                        self.result = "测试通知已清除。"
                    }
                }),
                Row(title: busy ? "正在执行…" : "最近操作", detail: result)
            ]),
            Section(title: "远程推送", footer: "只显示截断后的设备令牌。服务端登记地址必须使用 HTTPS；APNs 私钥只能保存在服务端。", rows: [
                Row(title: "APNs 注册", detail: remotePush.registrationStatus),
                Row(title: "设备令牌", detail: remotePush.tokenPreview),
                Row(title: "服务端登记", detail: remotePush.serverStatus),
                Row(title: "重新注册并登记", detail: "重新向 APNs 请求令牌并重试服务端登记", action: { [weak self] in
                    self?.perform {
                        await RemotePushService.shared.retry()
                    }
                })
            ]),
            Section(title: "连接与数据", footer: "刷新会读取学校真实数据，并执行正常低电量检查。", rows: [
                Row(title: "当前状态", detail: status),
                Row(title: "本机登录凭据", detail: model.hasSavedLogin ? "已保存（有效性以连接结果为准）" : "未保存"),
                Row(title: "学校会话 Cookie", detail: "\(cookies) 条"),
                Row(title: "最近刷新", detail: model.lastRefreshResult + (model.lastRefreshDuration.map { String(format: " · %.2f 秒", $0) } ?? "")),
                Row(title: "数据时间", detail: snapshot?.fetchedAt.formatted(date: .abbreviated, time: .standard) ?? "尚无数据"),
                Row(title: "电量与提醒值", detail: (snapshot.map { String(format: "剩余 %.2f 度", $0.purchasedKWh) } ?? "剩余未知") + String(format: " · 低于 %.0f 度提醒", model.lowBalanceThreshold)),
                Row(title: "低电量提醒状态", detail: model.reminderDiagnostic),
                Row(title: "数据条数", detail: "设备 \(snapshot?.meters.count ?? 0) · 用量 \(snapshot?.usageRecords.count ?? 0) · 充值 \(snapshot?.rechargeRecords.count ?? 0)"),
                Row(title: "重新读取电量", detail: model.status == .loading ? "正在刷新，请稍候" : "重新连接学校系统", action: { [weak self] in self?.model.refresh() })
            ]),
            Section(title: "运行环境", footer: nil, rows: [
                Row(title: "应用版本", detail: "\(version) (\(build))"),
                Row(title: "系统与设备", detail: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"),
                Row(title: "减少动态效果", detail: UIAccessibility.isReduceMotionEnabled ? "已开启" : "未开启")
            ]),
            Section(title: "本次运行日志", footer: "最多保留 60 条，重启清空。右上角可复制诊断报告；不包含账户、宿舍号、授权链接或 Cookie 内容。", rows: [
                Row(title: "最近事件", detail: PowerDiagnostics.shared.events.reversed().joined(separator: "\n").isEmpty ? "暂无事件" : PowerDiagnostics.shared.events.reversed().joined(separator: "\n"))
            ]),
            Section(title: "小组件", footer: "小组件通过 App Group 读取数据。免费 Apple ID 侧载时 App Group 可能签不上，此处会显示不可用。", rows: [
                Row(title: "共享存储", detail: PowerWidgetStore.isAvailable ? "可用（App Group 已生效）" : "不可用：签名缺少 App Group 权限，小组件读不到数据"),
                Row(title: "小组件扩展", detail: Bundle.main.builtInPlugInsURL.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) }?.first ?? "未随应用安装（签名时可能被移除或包标识符不匹配）"),
                Row(title: "已写入数据", detail: PowerWidgetStore.load().map { String(format: "%.2f 度 · 更新于 %@", $0.balanceKWh, $0.updatedAt.formatted(date: .omitted, time: .shortened)) } ?? "暂无"),
            ] + widgetPreviewRows),
        ]
        tableView.reloadData()
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        rebuildSections()
        Task { [weak self] in
            do { try await operation() }
            catch {
                self?.result = error.localizedDescription
                PowerDiagnostics.shared.record("调试操作失败：" + PowerDiagnostics.errorSummary(error))
            }
            self?.busy = false
            self?.reloadDiagnostics()
        }
    }

    private func requestPermission() {
        perform { [weak self] in
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            let status = await center.notificationSettings().authorizationStatus
            if [.authorized, .provisional, .ephemeral].contains(status) {
                await RemotePushService.shared.registerIfAuthorized()
            }
            self?.result = "当前权限：" + Self.authorizationText(status) + (status == .denied ? "。请前往系统设置开启。" : "。")
            PowerDiagnostics.shared.record("检查通知权限：" + Self.authorizationText(status))
        }
    }

    func sendTest(after delay: TimeInterval, lowBalance: Bool = false) {
        perform { [weak self] in
            guard let self else { return }
            try await self.notifications.send(after: delay, lowBalance: lowBalance)
            self.result = delay > 0 ? "系统已接受，将在 \(Int(delay)) 秒后发送。现在可以切到后台或锁屏。" : "系统已接受。请检查横幅或通知中心。"
        }
    }

    @objc private func copyReport() {
        let report = sections.map { section in
            section.title + "\n" + section.rows.filter { $0.action == nil && $0.title != "最近操作" && $0.title != "正在执行…" }
                .map { $0.title + ": " + $0.detail }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        UIPasteboard.general.string = "湖科电量诊断 · \(Date().formatted())\n\n" + report
        result = "诊断报告已复制。"
        rebuildSections()
        UIAccessibility.post(notification: .announcement, argument: "诊断报告已复制")
        let alert = UIAlertController(title: "已复制诊断报告", message: "可粘贴到反馈中，方便排查问题。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = PowerTheme.surface
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.detail
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.textColor = row.action == nil ? .label : PowerTheme.accent
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.selectionStyle = row.action == nil || busy ? .none : .default
        cell.accessoryType = row.action == nil ? .none : .disclosureIndicator
        if row.action != nil { cell.accessibilityTraits.insert(.button) }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy else { return }
        sections[indexPath.section].rows[indexPath.row].action?()
    }

    static func authorizationText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "尚未申请"
        case .denied: "已拒绝"
        case .authorized: "已允许"
        case .provisional: "临时授权（静默投递）"
        case .ephemeral: "临时 App Clip 授权"
        @unknown default: "未知"
        }
    }
    private static func settingText(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled: "开"
        case .disabled: "关"
        case .notSupported: "不支持"
        @unknown default: "未知"
        }
    }
}
