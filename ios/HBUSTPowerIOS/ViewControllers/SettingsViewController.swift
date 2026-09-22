import UIKit

final class SettingsViewController: ModelViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    /// The table is built from this description rather than from hardcoded index arithmetic: sections appear
    /// and disappear depending on what the build has configured, and index maths does not survive that.
    private struct Row {
        var title: String
        var detail: String?
        var symbol: String?
        var destructive = false
        var accessory: UITableViewCell.AccessoryType = .none
        /// A switch at the end of the row instead of a chevron.
        var toggle: Bool?
        var onToggle: ((Bool) -> Void)?
        var action: (() -> Void)?
    }

    private struct Section {
        var header: String
        var footer: String?
        var rows: [Row]
    }

    private var sections: [Section] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        connectScrolling(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        rebuild()
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        rebuild()
    }

    private func rebuild() {
        sections = makeSections()
        tableView.reloadData()
    }

    private func makeSections() -> [Section] {
        var result: [Section] = [
            Section(header: "外观", footer: "主题只改变颜色和一点小彩蛋。紫鸟紫、枫烻黄的配色来自朋友。", rows: [
                Row(title: "主题", detail: PowerTheme.style.name, symbol: "paintpalette.fill",
                    accessory: .disclosureIndicator,
                    action: { [weak self] in self?.push(ThemePickerViewController()) })
            ]),
            Section(header: "提醒",
                    footer: "打开应用或回到前台更新时，电量首次低于设定值时提醒一次；回升后再次变低会重新提醒。需允许系统通知。",
                    rows: [
                        Row(title: "低电量提醒", detail: String(format: "低于 %.0f 度", model.lowBalanceThreshold),
                            symbol: "bell.badge.fill", accessory: .disclosureIndicator,
                            action: { [weak self] in self?.editThreshold() })
                    ]),
            Section(header: "账户", footer: "登录信息仅保存在本机钥匙串。", rows: [
                Row(title: "重新登录智慧湖科", symbol: "person.crop.circle", accessory: .disclosureIndicator,
                    action: { [weak self] in self?.presentLogin() }),
                Row(title: "清除登录信息", symbol: "trash.fill", destructive: true,
                    action: { [weak self] in self?.confirmClearLogin() })
            ])
        ]

        if model.isUpdateCheckAvailable {
            result.append(Section(
                header: "更新",
                footer: "只读取作者站点上的一个版本信息文件，不上传任何内容；应用不会自行下载或安装，点“去下载”后在浏览器里完成。",
                rows: [
                    Row(title: "检查更新", detail: updateDetail, symbol: "arrow.down.circle",
                        accessory: .disclosureIndicator,
                        action: { [weak self] in self?.checkForUpdates() })
                ]
            ))
        }

        if model.isTelemetryAvailable {
            result.append(Section(
                header: "帮助改进",
                footer: "每天最多上报一次：应用版本、系统版本、设备型号和一个随机生成的安装标识。"
                    + "不含账号、宿舍号、电量或任何位置信息，也不读取设备识别码。关掉后本机标识一并删除，不影响任何功能。",
                rows: [
                    Row(title: "匿名使用统计", detail: model.telemetryEnabled ? "已开启" : "已关闭",
                        symbol: "chart.bar.fill",
                        toggle: model.telemetryEnabled,
                        onToggle: { [weak self] isOn in self?.model.setTelemetryEnabled(isOn) }),
                    Row(title: "看看会上报什么", detail: "逐项列出", symbol: "eye",
                        accessory: .disclosureIndicator,
                        action: { [weak self] in self?.showTelemetryPreview() })
                ]
            ))
        }

        result.append(Section(header: "调试", footer: nil, rows: [
            Row(title: "调试与诊断", detail: "通知 · 连接 · 日志", symbol: "stethoscope",
                accessory: .disclosureIndicator,
                action: { [weak self] in
                    guard let self else { return }
                    self.push(DebugViewController(model: self.model))
                })
        ]))

        result.append(Section(header: "关于", footer: nil, rows: [
            Row(title: "关于湖科电量", detail: "开发者的话 · 更新日志", symbol: "bolt.circle.fill",
                accessory: .disclosureIndicator,
                action: { [weak self] in
                    guard let self else { return }
                    self.push(AboutViewController(model: self.model))
                }),
            Row(title: "更新日志", detail: "版本 " + Changelog.latest.version, symbol: "list.bullet.rectangle",
                accessory: .disclosureIndicator,
                action: { [weak self] in self?.push(ChangelogViewController()) })
        ]))

        if let policy = CloudEndpoints.privacyPolicyURL {
            result[result.count - 1].rows.append(
                Row(title: "隐私政策", detail: "不上传电量数据 · 统计可关闭", symbol: "hand.raised.fill",
                    accessory: .disclosureIndicator,
                    action: { UIApplication.shared.open(policy) })
            )
        }

        return result
    }

    private var updateDetail: String {
        if model.cloudState.isChecking { return "正在检查…" }
        if let pending = model.pendingUpdate { return "有新版本 " + pending.versionName }
        guard model.cloudState.lastCheckedAt > 0 else { return "从未检查" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "上次检查 " + formatter.string(from: Date(timeIntervalSince1970: model.cloudState.lastCheckedAt))
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = PowerTheme.surface
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .subheadline)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = row.detail
        cell.imageView?.image = row.symbol.flatMap { UIImage(systemName: $0) }
        cell.imageView?.tintColor = row.destructive ? .systemRed : PowerTheme.accent
        cell.textLabel?.textColor = row.destructive ? .systemRed : .label
        cell.accessoryType = row.accessory

        if let isOn = row.toggle {
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.onTintColor = PowerTheme.accent
            toggle.addAction(UIAction { [weak self] action in
                guard let control = action.sender as? UISwitch else { return }
                self?.sections[indexPath.section].rows[indexPath.row].onToggle?(control.isOn)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sections[indexPath.section].rows[indexPath.row].action?()
    }

    // MARK: - Actions

    private func push(_ controller: UIViewController) {
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentLogin() {
        present(UINavigationController(rootViewController: AuthenticationViewController(model: model)), animated: true)
    }

    private func checkForUpdates() {
        guard !model.cloudState.isChecking else { return }
        let wasChecking = model.cloudState.lastCheckedAt
        model.checkForUpdates(.manual)
        // A manual check should say something either way; the launch check stays silent.
        Task { [weak self] in
            guard let self else { return }
            while self.model.cloudState.isChecking { try? await Task.sleep(for: .milliseconds(80)) }
            if let error = self.model.cloudState.error {
                self.presentNote(title: "检查更新失败", message: error)
            } else if let update = self.model.pendingUpdate {
                self.presentUpdate(update)
            } else if self.model.cloudState.lastCheckedAt >= wasChecking {
                self.presentNote(title: "已是最新版本", message: nil)
            }
        }
    }

    private func presentUpdate(_ update: CloudConfig.Update) {
        var lines: [String] = ["当前 \(Bundle.main.versionName)，最新 \(update.versionName)"]
        if model.mustUpgrade {
            lines.append("学校页面已经改版，这个版本可能读不到数据。")
        }
        lines.append(contentsOf: update.notes.map { "· " + $0 })
        if update.downloadURL == nil {
            lines.append("这份更新没有附带可用的下载地址，请到项目页面获取。")
        }

        let alert = UIAlertController(
            title: model.mustUpgrade ? "请更新到新版本" : "发现新版本 " + update.versionName,
            message: lines.joined(separator: "\n"),
            preferredStyle: .alert
        )
        if let url = update.downloadURL {
            alert.addAction(UIAlertAction(title: "去下载", style: .default) { _ in
                // iOS cannot install this itself; Safari takes over and the user sideloads from a computer.
                UIApplication.shared.open(url)
            })
        }
        alert.addAction(UIAlertAction(title: model.mustUpgrade ? "稍后" : "跳过这个版本",
                                      style: .cancel) { [weak self] _ in
            guard let self, !self.model.mustUpgrade else { return }
            self.model.skipUpdate()
        })
        present(alert, animated: true)
    }

    private func showTelemetryPreview() {
        let body = model.telemetryPreview().map { "\($0.0)：\($0.1)" }.joined(separator: "\n")
        let host = model.telemetryHost ?? "未配置"
        let alert = UIAlertController(
            title: "会上报这些",
            message: body + "\n\n发往 \(host)。除此之外不上报任何内容。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重置安装标识", style: .destructive) { [weak self] _ in
            self?.model.resetTelemetryID()
        })
        alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
        present(alert, animated: true)
    }

    private func presentNote(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private func editThreshold() {
        let alert = UIAlertController(title: "低电量提醒", message: "剩余电量低于多少度时提醒？", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.text = String(format: "%.0f", self.model.lowBalanceThreshold)
            field.placeholder = "例如 20"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, let value = Double(text), value.isFinite, value > 0 else { return }
            self.model.lowBalanceThreshold = value
        })
        present(alert, animated: true)
    }

    private func confirmClearLogin() {
        let alert = UIAlertController(title: "清除登录信息？", message: "下次查询时需要重新登录智慧湖科。", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in self.model.clearLogin() })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(alert, animated: true)
    }
}
