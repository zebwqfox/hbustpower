import UIKit

final class RecordsViewController: ModelViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var records: [RechargeRecord] = []
    private var rechargeItem: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "充值记录"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.sectionHeaderHeight = 42
        tableView.register(RecordCell.self, forCellReuseIdentifier: RecordCell.reuseIdentifier)
        tableView.register(SummaryCell.self, forCellReuseIdentifier: SummaryCell.reuseIdentifier)
        let recharge = UIBarButtonItem(
            title: "充值",
            image: UIImage(systemName: "plus.circle.fill"),
            primaryAction: UIAction { [weak self] _ in self?.rechargeTapped() }
        )
        recharge.tintColor = PowerTheme.accent
        rechargeItem = recharge
        navigationItem.rightBarButtonItem = recharge
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let refresh = ChargeRefreshControl()
        refresh.onRefresh = { [weak self] in self?.refreshPulled() }
        tableView.refreshControl = refresh
        view.addSubview(tableView)
        connectScrolling(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        modelDidChange()
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        let rechargeEnabled = model.isFeatureEnabled(CloudConfig.flagRecharge)
        navigationItem.rightBarButtonItem = rechargeEnabled ? rechargeItem : nil
        rechargeItem?.isEnabled = model.status != .loading
        if model.status != .loading { (tableView.refreshControl as? ChargeRefreshControl)?.finish(success: model.status == .ready) }
        records = model.snapshot?.rechargeRecords.sorted { $0.date > $1.date } ?? []
        tableView.reloadData()
        updateEmptyState()
    }

    // Section 0 is the summary card, section 1 the records.
    func numberOfSections(in tableView: UITableView) -> Int { records.isEmpty ? 0 : 2 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : records.count }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? 8 : 42 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return UIView() }
        let label = UILabel.powerLabel("最近记录", style: .headline, weight: .bold)
        let container = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SummaryCell.reuseIdentifier, for: indexPath) as! SummaryCell
            cell.configure(with: RechargeSummary(records: records))
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: RecordCell.reuseIdentifier, for: indexPath) as! RecordCell
        cell.configure(with: records[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool { indexPath.section == 1 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        navigationController?.pushViewController(detailController(for: records[indexPath.row]), animated: true)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == 1 else { return nil }
        let record = records[indexPath.row]
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: { [weak self] in
            self?.detailController(for: record)
        }) { [weak self] _ in
            let summary = "\(record.date.formatted(date: .abbreviated, time: .shortened)) \(record.type) \(record.amountText) · \(record.kWhText)"
            return UIMenu(children: [
                UIAction(title: "复制金额", image: UIImage(systemName: "yensign.circle")) { _ in UIPasteboard.general.string = record.amountText },
                UIAction(title: "复制这条记录", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = summary },
                UIAction(title: "分享", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    let activity = UIActivityViewController(activityItems: [summary], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                    self?.present(activity, animated: true)
                }
            ])
        }
    }

    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let preview = animator.previewViewController else { return }
        animator.addCompletion { [weak self] in self?.navigationController?.pushViewController(preview, animated: true) }
    }

    private func detailController(for record: RechargeRecord) -> UIViewController {
        let controller = UIViewController()
        controller.title = "记录详情"
        controller.view.backgroundColor = PowerTheme.background
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(scroll)
        let card = PowerCardView(spacing: 22, contentInsets: .init(top: 24, leading: 24, bottom: 24, trailing: 24))
        card.translatesAutoresizingMaskIntoConstraints = false
        var fields = [("充值类型", record.type), ("金额", record.amountText), ("电量", record.kWhText), ("宿舍", record.meterName), ("时间", record.date.formatted(date: .abbreviated, time: .shortened))]
        if let student = record.studentNumber { fields.append(("学工号", student)) }
        for (title, value) in fields { card.stack.addArrangedSubview(PowerTheme.heading(value, detail: title)) }
        scroll.addSubview(card)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: controller.view.topAnchor), scroll.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
            card.centerXAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.centerXAnchor),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            card.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            card.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        ])
        controller.preferredContentSize = CGSize(width: 360, height: CGFloat(fields.count) * 62 + 48)
        return controller
    }

    private func updateEmptyState() {
        guard records.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "tray")
        configuration.text = model.status == .loading ? "正在读取记录" : "暂无充值记录"
        switch model.status {
        case .authenticationRequired:
            configuration.text = "登录后查看记录"
            configuration.secondaryText = "连接智慧湖科，查看充值与补助明细。"
            configuration.button.title = "登录智慧湖科"
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.presentLoginIfNeeded() }
        case .error:
            configuration.text = "暂时无法读取记录"
            configuration.secondaryText = "检查网络后，下拉重试。"
        default:
            configuration.secondaryText = model.status == .loading ? "请稍候" : "充值与补助到账后，会显示在这里。"
        }
        let emptyView = UIContentUnavailableView(configuration: configuration)
        tableView.backgroundView = emptyView
    }

    @objc private func refreshPulled() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        model.refresh()
    }

    private func rechargeTapped() {
        guard model.isFeatureEnabled(CloudConfig.flagRecharge) else { return }
        guard model.status == .ready else {
            if model.status == .authenticationRequired { presentLoginIfNeeded() }
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let recharge = RechargeViewController(model: model) { [weak self] in
            self?.model.refresh()
        }
        let navigation = UINavigationController(rootViewController: recharge)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }
}

private final class RecordCell: UITableViewCell {
    static let reuseIdentifier = "recharge-record"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundColor = PowerTheme.surface
        selectionStyle = .default
        accessoryType = .disclosureIndicator
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(with record: RechargeRecord) {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = "\(record.amountText)  ·  \(record.kWhText)"
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        let details = [record.type, "\(record.meterName) · \(record.date.formatted(date: .abbreviated, time: .shortened))"]
        content.secondaryText = details.joined(separator: "\n")
        content.secondaryTextProperties.numberOfLines = 0
        content.textProperties.numberOfLines = 0
        content.directionalLayoutMargins = .init(top: 20, leading: 20, bottom: 20, trailing: 20)
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: record.type.contains("补助") ? "gift.fill" : "bolt.fill")
        content.imageProperties.tintColor = record.type.contains("补助") ? PowerTheme.accent : PowerTheme.accent
        content.imageProperties.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
        contentConfiguration = content
        let studentDescription = record.studentNumber.map { "，学工号 \($0)" } ?? ""
        accessibilityLabel = "\(record.type)，\(record.amountText)，\(record.kWhText)\(studentDescription)，\(record.meterName)，\(record.date.formatted(date: .abbreviated, time: .shortened))"
    }
}

/// Totals for everything the school returned on the current records page.
private final class SummaryCell: UITableViewCell {
    static let reuseIdentifier = "recharge-summary"
    private let total = UILabel.powerLabel(nil, style: .largeTitle, weight: .bold, color: PowerTheme.accent)
    private let caption = UILabel.powerLabel(nil, style: .subheadline, weight: .medium)
    private let detail = UILabel.powerLabel(nil, style: .footnote, color: .secondaryLabel)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = PowerTheme.hero
        selectionStyle = .none
        let bolt = UIImageView(image: UIImage(systemName: "bolt.circle.fill"))
        bolt.tintColor = PowerTheme.accent
        bolt.preferredSymbolConfiguration = .init(pointSize: 34, weight: .semibold)
        bolt.setContentHuggingPriority(.required, for: .horizontal)
        total.adjustsFontSizeToFitWidth = true
        total.minimumScaleFactor = 0.6
        total.numberOfLines = 1
        let labels = UIStackView(arrangedSubviews: [caption, total, detail])
        labels.axis = .vertical
        labels.spacing = 3
        let row = UIStackView(arrangedSubviews: [labels, bolt])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
        isAccessibilityElement = true
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(with summary: RechargeSummary) {
        caption.text = "最近 \(summary.count) 次充值与补助"
        total.text = summary.totalYuan.map { String(format: "¥%.2f", $0) } ?? "—"
        var parts: [String] = []
        if let kWh = summary.totalKWh { parts.append(String(format: "合计 %.1f 度", kWh)) }
        if let yuan = summary.totalYuan, summary.count > 1 { parts.append(String(format: "平均每次 ¥%.2f", yuan / Double(summary.count))) }
        if let latest = summary.latest {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: latest), to: Calendar.current.startOfDay(for: .now)).day ?? 0
            parts.append(days <= 0 ? "今天刚充过" : "上次在 \(days) 天前")
        }
        detail.text = parts.joined(separator: " · ")
        accessibilityLabel = [caption.text, total.text, detail.text].compactMap { $0 }.joined(separator: "，")
    }
}
