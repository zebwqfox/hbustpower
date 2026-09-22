import UIKit

final class OverviewViewController: ModelViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let dashboard = UIStackView()
    private let welcome = UIStackView()
    private let connection = UIStackView()
    private let connectionSpinner = UIActivityIndicatorView(style: .large)
    private let connectionTitle = UILabel.powerLabel(nil, style: .title2, weight: .semibold)
    private let connectionDetail = UILabel.powerLabel(nil, style: .body, color: .secondaryLabel)
    private let retryButton = PowerTheme.button("重新连接", image: "arrow.clockwise", primary: true)
    private let heroView = BalanceHeroView()
    private let lightingTile = MetricTileView(title: "照明", icon: "lightbulb", tint: PowerTheme.lighting)
    private let acTile = MetricTileView(title: "空调", icon: "snowflake", tint: PowerTheme.cooling)
    private let meterStack = UIStackView()
    private let statusLabel = UILabel.powerLabel(nil, style: .footnote, color: .secondaryLabel)
    private let welcomeTitle = UILabel.powerLabel("宿舍用电，\n心里有数。", style: .largeTitle, weight: .semibold)
    private let welcomeDetail = UILabel.powerLabel(nil, style: .body, color: .secondaryLabel)
    private let welcomeButton = PowerTheme.button("登录智慧湖科", image: "arrow.right", primary: true)
    private let rechargeButton = PowerTheme.button("电费充值", image: "plus", primary: true)
    private let planButton = PowerTheme.button("算一算", image: "yensign.circle")
    private let sessionButton = PowerTheme.button("重新登录", image: "person.crop.circle")
    private let metrics = UIStackView()
    private let insightsSection = UIStackView()
    private let insightsRow = UIStackView()
    private var shownInsights: [UsageInsight] = []
    private var hasRevealed = false
    private lazy var hingeWidth = primaryColumn.widthAnchor.constraint(equalToConstant: 0)
    private let primaryColumn = UIStackView()
    private let secondaryColumn = UIStackView()
    private let insightsScroller = UIScrollView()
    private lazy var maxWidth = contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: PowerLayout.readableWidth)
    private let quoteView = StrayBirdsCardView()
    private let illustration = PowerIllustrationView()
    private lazy var illustrationHeight = illustration.heightAnchor.constraint(equalToConstant: 240)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "电量"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        installRefreshButton()
        configureLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: OverviewViewController, _) in
            controller.updateMetricLayout()
        }
        applyAdaptiveLayout()
        registerForTraitChanges(PowerLayout.traits) { (controller: OverviewViewController, _) in controller.applyAdaptiveLayout() }
        modelDidChange()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasRevealed {
            hasRevealed = true
            let elements = !dashboard.isHidden ? primaryColumn.arrangedSubviews + secondaryColumn.arrangedSubviews.prefix(2) : (!welcome.isHidden ? welcome.arrangedSubviews : connection.arrangedSubviews)
            PowerMotion.reveal(elements)
        }
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        let loading = model.status == .loading
        navigationItem.rightBarButtonItem?.isEnabled = !loading
        if !loading { (scrollView.refreshControl as? ChargeRefreshControl)?.finish(success: model.status == .ready) }
        dashboard.isHidden = model.snapshot == nil
        welcome.isHidden = model.snapshot != nil || model.status != .authenticationRequired
        connection.isHidden = model.snapshot != nil || model.status == .authenticationRequired
        sessionButton.isHidden = model.status != .authenticationRequired
        rechargeButton.isEnabled = model.status == .ready
        planButton.isEnabled = model.snapshot != nil

        guard let snapshot = model.snapshot else {
            updateWelcome()
            updateConnection()
            return
        }
        heroView.update(snapshot, threshold: model.lowBalanceThreshold)
        lightingTile.value = snapshot.recentAverage(kind: "照明")
        acTile.value = snapshot.recentAverage(kind: "空调")
        updateInsights(UsageInsights.make(from: snapshot))
        rebuildMeters(snapshot.meters)
        let updated = "更新于 " + snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)
        switch model.status {
        case .loading: statusLabel.text = "正在更新… · " + updated
        case .authenticationRequired: statusLabel.text = "登录已过期 · 当前显示上次数据"
        case .error: statusLabel.text = "更新失败，下拉重试 · " + updated
        default: statusLabel.text = updated + " · 下拉刷新"
        }
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        let refreshControl = ChargeRefreshControl()
        refreshControl.onRefresh = { [weak self] in self?.model.refresh() }
        refreshControl.onFinished = { [weak self] in self?.heroView.celebrate() }
        scrollView.refreshControl = refreshControl
        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        connectScrolling(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            maxWidth
        ])
        let width = contentStack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = UILayoutPriority(999)
        width.isActive = true
        dashboard.accessibilityIdentifier = "overview.dashboard"
        welcome.accessibilityIdentifier = "overview.login"
        connection.accessibilityIdentifier = "overview.connection"
        contentStack.addArrangedSubview(connection)
        contentStack.addArrangedSubview(welcome)
        contentStack.addArrangedSubview(dashboard)
        // The night-fur theme opens with a line from Stray Birds, a new one each launch.
        quoteView.isHidden = PowerTheme.style != .purpleBird
        contentStack.setCustomSpacing(26, after: dashboard)
        contentStack.addArrangedSubview(quoteView)
        configureConnection()
        configureWelcome()

        dashboard.axis = .vertical
        dashboard.spacing = 30
        for column in [primaryColumn, secondaryColumn] {
            column.axis = .vertical
            column.spacing = 16
            dashboard.addArrangedSubview(column)
        }
        primaryColumn.addArrangedSubview(heroView)
        heroView.onStickerTap = { [weak self] in
            guard let self else { return }
            PowerMotion.replaceText(on: self.statusLabel, with: PowerTheme.style.greeting)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in self?.modelDidChange() }
        }
        heroView.onExpansion = { [weak self] in
            guard let self else { return }
            PowerMotion.animate { self.view.layoutIfNeeded() }
        }
        let rechargeRow = UIStackView(arrangedSubviews: [rechargeButton, planButton])
        rechargeRow.spacing = 10
        planButton.setContentHuggingPriority(.required, for: .horizontal)
        planButton.accessibilityLabel = "充多少合适，算一算"
        primaryColumn.addArrangedSubview(rechargeRow)
        rechargeButton.addTarget(self, action: #selector(rechargeTapped), for: .touchUpInside)
        planButton.addAction(UIAction { [weak self] _ in self?.showPlanner() }, for: .touchUpInside)
        let usageHeader = DoodleHeadingView("每天用了多少", detail: "最近 7 个有记录日的平均用量", seed: 3)
        secondaryColumn.addArrangedSubview(usageHeader)
        metrics.addArrangedSubview(lightingTile)
        metrics.addArrangedSubview(acTile)
        lightingTile.addAction(UIAction { [weak self] _ in self?.showUsage(kind: "照明") }, for: .touchUpInside)
        acTile.addAction(UIAction { [weak self] _ in self?.showUsage(kind: "空调") }, for: .touchUpInside)
        metrics.spacing = 12
        metrics.distribution = .fillEqually
        secondaryColumn.addArrangedSubview(metrics)
        updateMetricLayout()
        let usageButton = PowerTheme.button("查看用量趋势", image: "chart.xyaxis.line")
        usageButton.addAction(UIAction { [weak self] _ in self?.tabBarController?.selectedIndex = 1 }, for: .touchUpInside)
        secondaryColumn.addArrangedSubview(usageButton)
        secondaryColumn.setCustomSpacing(30, after: usageButton)
        configureInsights()
        secondaryColumn.addArrangedSubview(insightsSection)
        secondaryColumn.setCustomSpacing(30, after: insightsSection)
        attachMenus()
        secondaryColumn.addArrangedSubview(PowerTheme.heading("设备状态"))
        meterStack.axis = .vertical
        meterStack.spacing = 0
        let meterCard = PowerCardView(spacing: 0, contentInsets: .zero)
        meterCard.stack.addArrangedSubview(meterStack)
        secondaryColumn.addArrangedSubview(meterCard)
        statusLabel.textAlignment = .center
        statusLabel.accessibilityTraits = .updatesFrequently
        secondaryColumn.addArrangedSubview(statusLabel)
        sessionButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        secondaryColumn.addArrangedSubview(sessionButton)
    }

    private func configureWelcome() {
        welcome.axis = .vertical
        welcome.spacing = 20
        illustrationHeight.isActive = true
        welcome.addArrangedSubview(illustration)
        welcomeTitle.font = PowerTheme.font(34, weight: .semibold, style: .largeTitle)
        welcomeTitle.textAlignment = .center
        welcomeDetail.textAlignment = .center
        welcome.addArrangedSubview(welcomeTitle)
        welcome.addArrangedSubview(welcomeDetail)
        welcome.setCustomSpacing(34, after: welcomeDetail)
        welcomeButton.addTarget(self, action: #selector(welcomeTapped), for: .touchUpInside)
        welcome.addArrangedSubview(welcomeButton)
        let note = UILabel.powerLabel("通过学校账户连接 · 登录信息保存在本机", style: .caption1, color: .secondaryLabel)
        note.textAlignment = .center
        welcome.addArrangedSubview(note)
    }

    private func configureConnection() {
        connection.axis = .vertical
        connection.spacing = 20
        connection.isLayoutMarginsRelativeArrangement = true
        connection.directionalLayoutMargins = .init(top: 100, leading: 0, bottom: 60, trailing: 0)
        connectionSpinner.color = PowerTheme.accent
        connectionTitle.textAlignment = .center
        connectionDetail.textAlignment = .center
        [connectionSpinner, connectionTitle, connectionDetail, retryButton].forEach(connection.addArrangedSubview)
        retryButton.addAction(UIAction { [weak self] _ in self?.model.refresh() }, for: .touchUpInside)
    }

    private func updateConnection() {
        guard !connection.isHidden else {
            connectionSpinner.stopAnimating()
            return
        }
        if case .error = model.status {
            connectionSpinner.stopAnimating()
            connectionTitle.text = "暂时无法更新"
            connectionDetail.text = "检查网络后再试一次。\n已有登录信息会继续保留。"
            retryButton.isHidden = false
        } else {
            connectionSpinner.startAnimating()
            connectionTitle.text = "正在读取电量"
            connectionDetail.text = "正在恢复连接，请稍候…"
            retryButton.isHidden = true
        }
    }

    private func updateWelcome() {
        welcomeDetail.text = "看看还剩多少电、还能用多久。\n照明与空调用量，一眼看清。"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        alignColumnsToHinge()
    }

    /// On a half-folded iPhone Duo, put the gap between the two columns exactly over the fold so no card or button
    /// sits on it. Flat devices, one-column layouts and systems without reserved regions keep the even split.
    private func alignColumnsToHinge() {
        var hinge: CGRect?
        if #available(iOS 27.1, *), dashboard.axis == .horizontal {
            hinge = view.reservedRegions(kind: .division)
                .filter { $0.isActive && $0.frame.height > $0.frame.width }
                .map { dashboard.convert($0.frame, from: view) }
                .first { $0.minX > 160 && $0.maxX < dashboard.bounds.width - 160 }
        }
        if let hinge {
            let aligned = hingeWidth.isActive && dashboard.distribution == .fill
                && abs(hingeWidth.constant - hinge.minX) < 0.5 && abs(dashboard.spacing - hinge.width) < 0.5
            guard !aligned else { return }
            dashboard.distribution = .fill
            dashboard.spacing = hinge.width
            hingeWidth.constant = hinge.minX
            hingeWidth.isActive = true
        } else if hingeWidth.isActive {
            hingeWidth.isActive = false
            applyAdaptiveLayout()
        }
    }


    private func applyAdaptiveLayout() {
        if hingeWidth.isActive, !PowerLayout.isWide(traitCollection) { hingeWidth.isActive = false }
        let wide = PowerLayout.isWide(traitCollection), short = PowerLayout.isShort(traitCollection)
        // Regular width (unfolded, iPad): balance and details side by side in an even split; when half-folded,
        // alignColumnsToHinge() moves the gap onto the fold. Compact width (outer display, iPhone): one column.
        maxWidth.constant = wide ? PowerLayout.wideWidth : PowerLayout.readableWidth
        dashboard.axis = wide ? .horizontal : .vertical
        dashboard.alignment = wide ? .top : .fill
        dashboard.distribution = wide ? .fillEqually : .fill
        dashboard.spacing = wide ? 32 : 30
        // Cards scrolling past the edge look good full-bleed, but not across the other column.
        updateInsightsClipping()
        illustrationHeight.constant = short ? 170 : 240
        connection.directionalLayoutMargins.top = short ? 36 : 100
    }

    private func updateMetricLayout() {
        metrics.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    private func rebuildMeters(_ meters: [MeterStatus]) {
        meterStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if meters.isEmpty {
            let empty = PowerTheme.heading("暂无设备信息", detail: "学校返回设备状态后会显示在这里")
            empty.isLayoutMarginsRelativeArrangement = true
            empty.directionalLayoutMargins = .init(top: 20, leading: 20, bottom: 20, trailing: 20)
            meterStack.addArrangedSubview(empty)
        }
        for (index, meter) in meters.enumerated() {
            if index > 0 {
                let line = UIView()
                line.backgroundColor = .separator
                line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                meterStack.addArrangedSubview(line)
            }
            meterStack.addArrangedSubview(MeterRowView(meter: meter))
        }
    }

    private func configureInsights() {
        insightsSection.axis = .vertical
        insightsSection.spacing = 14
        insightsSection.addArrangedSubview(DoodleHeadingView("用电小发现", detail: "左右滑动，长按可以复制", seed: 11))
        let scroller = insightsScroller
        scroller.showsHorizontalScrollIndicator = false
        scroller.alwaysBounceHorizontal = true
        scroller.clipsToBounds = false
        insightsRow.spacing = 12
        insightsRow.alignment = .fill
        insightsRow.translatesAutoresizingMaskIntoConstraints = false
        scroller.addSubview(insightsRow)
        NSLayoutConstraint.activate([
            insightsRow.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            insightsRow.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            insightsRow.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor, constant: 10),
            insightsRow.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor, constant: -4),
            scroller.frameLayoutGuide.heightAnchor.constraint(equalTo: insightsRow.heightAnchor, constant: 14)
        ])
        insightsSection.addArrangedSubview(scroller)
    }

    private func updateInsights(_ insights: [UsageInsight]) {
        insightsSection.isHidden = insights.isEmpty
        guard insights != shownInsights else { return }
        shownInsights = insights
        insightsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, insight) in insights.enumerated() {
            let card = InsightCardView(insight: insight, stickerAngle: index.isMultiple(of: 2) ? 0.1 : -0.09)
            card.addAction(UIAction { [weak self, weak card] _ in
                card?.bounce()
                self?.openInsight(insight)
            }, for: .touchUpInside)
            MenuAttachment.attach(to: card) {
                UIMenu(children: [UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = "\(insight.caption)：\(insight.value)"
                }])
            }
            insightsRow.addArrangedSubview(card)
        }
        if hasRevealed { PowerMotion.reveal(insightsRow.arrangedSubviews) }
    }

    private func openInsight(_ insight: UsageInsight) {
        switch insight.id {
        case "ac": showUsage(kind: "空调")
        case "recharge": tabBarController?.selectedIndex = 2
        case "value": heroView.celebrate()
        default: tabBarController?.selectedIndex = 1
        }
    }

    private func attachMenus() {
        MenuAttachment.attach(to: heroView) { [weak self] in
            guard let self, let snapshot = self.model.snapshot else { return nil }
            let summary = self.heroView.summaryText
            return UIMenu(children: [
                UIAction(title: "复制电量", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = summary },
                UIAction(title: "分享电量卡片", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in self?.shareCard(snapshot) },
                UIAction(title: "查看用量趋势", image: UIImage(systemName: "chart.xyaxis.line")) { [weak self] _ in self?.tabBarController?.selectedIndex = 1 },
                UIAction(title: "算算充多少", image: UIImage(systemName: "yensign.circle")) { [weak self] _ in self?.showPlanner() },
                UIAction(title: "刷新", image: UIImage(systemName: "arrow.clockwise"), attributes: self.model.status == .loading ? .disabled : []) { [weak self] _ in self?.model.refresh() }
            ])
        }
        for (tile, kind) in [(lightingTile, "照明"), (acTile, "空调")] {
            MenuAttachment.attach(to: tile) { [weak self, weak tile] in
                guard let value = tile?.value else { return nil }
                return UIMenu(children: [
                    UIAction(title: "复制日均用量", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = String(format: "\(kind)日均 %.2f 度", value) },
                    UIAction(title: "查看\(kind)趋势", image: UIImage(systemName: "chart.bar.xaxis")) { [weak self] _ in self?.showUsage(kind: kind) }
                ])
            }
        }
    }

    private func showPlanner() {
        guard presentedViewController == nil else { return }
        let planner = RechargePlannerViewController(snapshot: model.snapshot) { [weak self] in self?.rechargeTapped() }
        let navigation = UINavigationController(rootViewController: planner)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(navigation, animated: true)
    }

    // Scrolling cards may run to the screen edge, but not under a vertical bar or a side inset (iPhone Duo outer display).
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateInsightsClipping()
    }

    private func updateInsightsClipping() {
        let insets = view.safeAreaInsets
        insightsScroller.clipsToBounds = PowerLayout.isWide(traitCollection) || insets.left > 0 || insets.right > 0
    }

    private func shareCard(_ snapshot: ElectricitySnapshot) {
        let image = ShareCardRenderer.image(room: snapshot.room ?? "我的宿舍", balance: snapshot.purchasedKWh, forecast: heroView.forecastText,
                                            isLow: snapshot.purchasedKWh < model.lowBalanceThreshold, traits: traitCollection)
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = heroView
        present(activity, animated: true)
    }

    private func showUsage(kind: String) {
        guard let navigation = tabBarController?.viewControllers?[1] as? UINavigationController,
              let usage = navigation.viewControllers.first as? UsageViewController else { return }
        usage.loadViewIfNeeded()
        usage.focus(on: kind)
        tabBarController?.selectedIndex = 1
    }

    @objc private func welcomeTapped() {
        loginTapped()
    }
    @objc private func loginTapped() {
        guard presentedViewController == nil else { return }
        present(UINavigationController(rootViewController: AuthenticationViewController(model: model)), animated: true)
    }
    @objc private func rechargeTapped() {
        guard model.status == .ready else { return }
        let recharge = RechargeViewController { [weak self] in self?.model.refresh() }
        let navigation = UINavigationController(rootViewController: recharge)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }
}

private final class BalanceHeroView: PowerInteractiveControl {
    var onExpansion: (() -> Void)?
    private let explanationLabel = UILabel.powerLabel(nil, style: .subheadline, color: PowerTheme.accent)
    private let disclosureLabel = UILabel.powerLabel("轻点查看用量估算 ↓", style: .caption1, color: PowerTheme.accent)
    private var expanded = false
    private let roomLabel = UILabel.powerLabel(nil, style: .subheadline, weight: .medium, color: PowerTheme.accent)
    private let balanceLabel = UILabel.powerLabel("—", style: .largeTitle, weight: .medium, color: PowerTheme.accent)
    private let forecastLabel = UILabel.powerLabel(nil, style: .headline, weight: .medium, color: PowerTheme.accent)
    private let detailLabel = UILabel.powerLabel(nil, style: .caption1, color: .secondaryLabel)
    private let liquid = EnergyLiquidView()
    private let sticker = StickerView(nil, angle: 0.12)
    /// Lets the page say something in the theme's voice when the sticker is poked.
    var onStickerTap: (() -> Void)?
    var summaryText: String { "\(roomLabel.text ?? "") 剩余 \(balanceLabel.text ?? "—") 度，\(forecastLabel.text ?? "")" }
    var forecastText: String { forecastLabel.text ?? "" }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = PowerTheme.hero
        let effect = UIGlassEffect()
        effect.tintColor = PowerTheme.accent.withAlphaComponent(0.05)
        effect.isInteractive = true
        let material = UIVisualEffectView(effect: effect)
        material.isUserInteractionEnabled = false
        material.cornerConfiguration = .uniformCorners(radius: .fixed(30))
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)
        NSLayoutConstraint.activate([
            material.leadingAnchor.constraint(equalTo: leadingAnchor), material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.topAnchor.constraint(equalTo: topAnchor), material.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer.cornerRadius = 30
        layer.cornerCurve = .continuous
        liquid.layer.cornerRadius = 30
        liquid.layer.cornerCurve = .continuous
        liquid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(liquid)
        NSLayoutConstraint.activate([
            liquid.leadingAnchor.constraint(equalTo: leadingAnchor), liquid.trailingAnchor.constraint(equalTo: trailingAnchor),
            liquid.topAnchor.constraint(equalTo: topAnchor), liquid.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        let push = UIPanGestureRecognizer(target: self, action: #selector(pushed(_:)))
        addGestureRecognizer(push)
        let eyebrow = UILabel.powerLabel("剩余电量", style: .subheadline, color: PowerTheme.accent)
        balanceLabel.font = PowerTheme.font(58, weight: .medium, style: .largeTitle)
        balanceLabel.numberOfLines = 1
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.minimumScaleFactor = 0.45
        balanceLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let unit = UILabel.powerLabel("度", style: .title3, color: PowerTheme.accent)
        let balanceRow = UIStackView(arrangedSubviews: [balanceLabel, unit])
        balanceRow.spacing = 7
        balanceRow.alignment = .firstBaseline
        balanceRow.distribution = .fill
        unit.setContentHuggingPriority(.required, for: .horizontal)
        let valueHost = UIStackView(arrangedSubviews: [balanceRow])
        valueHost.axis = .vertical
        valueHost.alignment = .center
        let line = UIView()
        line.backgroundColor = PowerTheme.accent.withAlphaComponent(0.15)
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let stack = UIStackView(arrangedSubviews: [roomLabel, eyebrow, valueHost, forecastLabel, disclosureLabel, explanationLabel, line, detailLabel])
        stack.isUserInteractionEnabled = false
        explanationLabel.isHidden = true
        explanationLabel.textAlignment = .center
        disclosureLabel.textAlignment = .center
        addTarget(self, action: #selector(toggleExplanation), for: .touchUpInside)
        stack.axis = .vertical
        stack.spacing = 9
        stack.setCustomSpacing(22, after: roomLabel)
        stack.setCustomSpacing(20, after: forecastLabel)
        stack.setCustomSpacing(14, after: line)
        [roomLabel, eyebrow, forecastLabel, detailLabel].forEach { $0.textAlignment = .center }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
            balanceRow.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor)
        ])
        sticker.translatesAutoresizingMaskIntoConstraints = false
        sticker.addAction(UIAction { [weak self] _ in
            self?.liquid.slosh(0.9)
            self?.onStickerTap?()
        }, for: .touchUpInside)
        addSubview(sticker)
        NSLayoutConstraint.activate([
            sticker.topAnchor.constraint(equalTo: topAnchor, constant: -8),
            sticker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 6)
        ])
        isAccessibilityElement = true
        accessibilityTraits = [.button, .summaryElement]
        accessibilityHint = "轻点展开或收起用量估算说明"
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func pushed(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began, .changed: liquid.push(gesture.translation(in: self).x / max(1, bounds.width / 2))
        default: liquid.push(nil)
        }
    }

    /// Only horizontal drags push the liquid; vertical drags keep scrolling the page.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y) * 1.3
    }

    func celebrate() {
        liquid.slosh(1.2)
        sticker.wiggle()
    }

    @objc private func toggleExplanation() {
        liquid.slosh(0.6)
        superview?.layoutIfNeeded()
        expanded.toggle()
        disclosureLabel.text = expanded ? "收起估算说明 ↑" : "轻点查看用量估算 ↓"
        accessibilityValue = expanded ? explanationLabel.text : "估算说明已收起"
        PowerMotion.animate {
            self.explanationLabel.isHidden = !self.expanded
            self.superview?.layoutIfNeeded()
        }
        onExpansion?()
    }

    func update(_ snapshot: ElectricitySnapshot, threshold: Double) {
        roomLabel.text = snapshot.room ?? "我的宿舍"
        PowerMotion.replaceText(on: balanceLabel, with: String(format: "%.2f", snapshot.purchasedKWh))
        let isLow = snapshot.purchasedKWh < threshold
        if let lighting = snapshot.recentAverage(kind: "照明"), let ac = snapshot.recentAverage(kind: "空调"), lighting + ac > 0 {
            explanationLabel.text = String(format: "近期日均 %.2f 度。剩余电量 ÷ 日均用量，即为预计天数；实际时长会随用电变化。", lighting + ac)
        } else {
            explanationLabel.text = "有照明和空调的用量记录后，会根据剩余电量与日均用量估算可用天数。"
        }
        forecastLabel.text = snapshot.predictedDays.map { String(format: "按近期用量，约可用 %.1f 天", $0) } ?? "用量记录充足后，可估算使用天数"
        if isLow { forecastLabel.text = "电量偏低，记得及时充值" }
        forecastLabel.textColor = isLow ? PowerTheme.lighting : PowerTheme.accent
        // A month of forecast fills the card; without a forecast, 300 kWh does.
        liquid.level = snapshot.predictedDays.map { CGFloat($0 / 30) } ?? CGFloat(snapshot.purchasedKWh / 300)
        liquid.isLow = isLow
        let days = snapshot.predictedDays ?? .infinity
        sticker.text = isLow || days < 3 ? "该充电啦" : (days < 10 ? "省着点用" : "电量充足")
        sticker.fill = isLow || days < 3 ? PowerTheme.lighting : PowerTheme.accent
        var details: [String] = []
        if let subsidy = snapshot.subsidyKWh { details.append(String(format: "补助 %.2f 度", subsidy)) }
        if let price = snapshot.unitPrice { details.append(String(format: "电价 %.2f 元/度", price)) }
        detailLabel.text = details.joined(separator: "  ·  ")
        detailLabel.isHidden = details.isEmpty
        accessibilityLabel = "\(sticker.text ?? "")。\(roomLabel.text ?? "")，剩余电量 \(balanceLabel.text ?? "") 度。\(forecastLabel.text ?? "")。\(detailLabel.text ?? "")"
    }
}

private final class MetricTileView: PowerInteractiveControl {
    private let valueLabel = UILabel.powerLabel("—", style: .title1, weight: .medium)
    var value: Double? {
        didSet {
            valueLabel.text = value.map { String(format: "%.2f", $0) } ?? "—"
            accessibilityValue = value.map { String(format: "%.2f 度每天", $0) } ?? "暂无数据"
        }
    }
    init(title: String, icon: String, tint: UIColor) {
        super.init(frame: .zero)
        let glass = UIGlassEffect()
        glass.tintColor = PowerTheme.surface.withAlphaComponent(0.3)
        glass.isInteractive = true
        let material = UIVisualEffectView(effect: glass)
        material.isUserInteractionEnabled = false
        material.cornerConfiguration = .uniformCorners(radius: .fixed(22))
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)
        NSLayoutConstraint.activate([
            material.leadingAnchor.constraint(equalTo: leadingAnchor), material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.topAnchor.constraint(equalTo: topAnchor), material.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = tint
        symbol.preferredSymbolConfiguration = .init(pointSize: 18, weight: .medium)
        symbol.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [symbol, UILabel.powerLabel(title, style: .subheadline, color: .secondaryLabel), UIView()])
        header.alignment = .center
        header.spacing = 8
        valueLabel.font = PowerTheme.font(30, weight: .medium, style: .title1)
        let stack = UIStackView(arrangedSubviews: [header, valueLabel, UILabel.powerLabel("度 / 天  ↗", style: .caption1, color: .secondaryLabel)])
        stack.isUserInteractionEnabled = false
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(16, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "\(title)每日平均用量"
        accessibilityTraits = .button
        accessibilityHint = "轻点查看该项用量趋势"
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

private final class MeterRowView: UIView {
    init(meter: MeterStatus) {
        super.init(frame: .zero)
        let isAC = meter.name.contains("空调")
        let symbol = UIImageView(image: UIImage(systemName: isAC ? "snowflake" : "lightbulb"))
        symbol.tintColor = isAC ? PowerTheme.cooling : PowerTheme.lighting
        symbol.contentMode = .center
        symbol.widthAnchor.constraint(equalToConstant: 26).isActive = true
        let labels = PowerTheme.heading(meter.name, detail: "\(meter.powerStatus) · \(meter.communicationStatus)")
        let row = UIStackView(arrangedSubviews: [symbol, labels])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18), row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "\(meter.name)，\(meter.powerStatus)，\(meter.communicationStatus)"
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

private final class InsightCardView: PowerInteractiveControl {
    init(insight: UsageInsight, stickerAngle: CGFloat) {
        super.init(frame: .zero)
        backgroundColor = PowerTheme.surface
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        let tint: UIColor = switch insight.tone {
        case .good: .systemGreen
        case .heads: PowerTheme.lighting
        case .neutral: PowerTheme.accent
        }
        let symbol = UIImageView(image: UIImage(systemName: insight.symbol))
        symbol.tintColor = tint
        symbol.preferredSymbolConfiguration = .init(pointSize: 17, weight: .semibold)
        symbol.contentMode = .left
        let value = UILabel.powerLabel(insight.value, style: .title3, weight: .bold)
        value.numberOfLines = 1
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.7
        let caption = UILabel.powerLabel(insight.caption, style: .footnote, color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [symbol, value, caption, UIView()])
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(12, after: symbol)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 164),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        if let text = insight.sticker {
            let sticker = StickerView(text, angle: stickerAngle)
            sticker.fill = tint
            sticker.isUserInteractionEnabled = false
            sticker.translatesAutoresizingMaskIntoConstraints = false
            addSubview(sticker)
            NSLayoutConstraint.activate([
                sticker.topAnchor.constraint(equalTo: topAnchor, constant: -10),
                sticker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4)
            ])
        }
        isAccessibilityElement = true
        accessibilityLabel = [insight.sticker, insight.caption, insight.value].compactMap { $0 }.joined(separator: "，")
        accessibilityTraits = .button
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func bounce() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        transform = CGAffineTransform(scaleX: 0.94, y: 0.94).rotated(by: 0.02)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 3, options: [.allowUserInteraction]) {
            self.transform = .identity
        }
    }
}
