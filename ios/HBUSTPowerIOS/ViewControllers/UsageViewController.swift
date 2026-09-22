import UIKit

final class UsageViewController: ModelViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let chart = UsageChartView()
    private var adaptiveRows: [UIStackView] = []
    private let lightingLegend = PowerActionButton(type: .system)
    private let acLegend = PowerActionButton(type: .system)
    private let selectedDayLabel = UILabel.powerLabel("轻点或横向滑动图表，查看当天用量", style: .subheadline, color: PowerTheme.accent)
    private let clearSelectionButton = PowerTheme.button("查看整周", image: "arrow.uturn.backward")
    private var hasRevealed = false
    private lazy var maxWidth = stack.widthAnchor.constraint(lessThanOrEqualToConstant: PowerLayout.readableWidth)
    private lazy var chartHeight = chart.heightAnchor.constraint(equalToConstant: 198)
    private let rangeNoteLabel = UILabel.powerLabel("", style: .caption1, color: .secondaryLabel)
    private let lightingTotalLabel = UILabel.powerLabel("—", style: .title2, weight: .bold)
    private let acTotalLabel = UILabel.powerLabel("—", style: .title2, weight: .bold)
    private let sharePercentLabel = UILabel.powerLabel("—", style: .largeTitle, weight: .bold, color: PowerTheme.cooling)
    private let shareDetailLabel = UILabel.powerLabel("", style: .caption1, color: .secondaryLabel)
    private let dailyAverageLabel = UILabel.powerLabel("—", style: .headline, weight: .semibold)
    private let trendLabel = UILabel.powerLabel("—", style: .headline, weight: .semibold)
    private let peakLabel = UILabel.powerLabel("—", style: .headline, weight: .semibold)
    private let statusLabel = UILabel.powerLabel("尚未更新", style: .footnote, color: .secondaryLabel)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "用量"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        installRefreshButton()
        configureLegendButtons()
        configureLayout()
        chart.selectionChanged = { [weak self] point in self?.updateSelectedDay(point) }
        updateAdaptiveLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: UsageViewController, _) in
            controller.updateAdaptiveLayout()
        }
        applyAdaptiveLayout()
        registerForTraitChanges(PowerLayout.traits) { (controller: UsageViewController, _) in controller.applyAdaptiveLayout() }
        modelDidChange()
    }

    private func applyAdaptiveLayout() {
        let wide = PowerLayout.isWide(traitCollection)
        maxWidth.constant = wide ? PowerLayout.wideWidth : PowerLayout.readableWidth
        chartHeight.constant = wide ? 280 : (PowerLayout.isShort(traitCollection) ? 170 : 198)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasRevealed {
            hasRevealed = true
            PowerMotion.reveal(Array(stack.arrangedSubviews.prefix(3)))
        }
    }

    func focus(on kind: String) {
        lightingLegend.isSelected = kind == "照明"
        acLegend.isSelected = kind == "空调"
        chart.showsLighting = lightingLegend.isSelected
        chart.showsAirConditioning = acLegend.isSelected
        chart.clearSelection()
        updateLegendAppearance()
    }

    private func updateSelectedDay(_ point: DailyUsagePoint?) {
        if let point {
            selectedDayLabel.text = String(format: "%@ · 合计 %.2f 度\n照明 %.2f 度   空调 %.2f 度", point.date.formatted(.dateTime.month().day()), point.total, point.lighting, point.airConditioning)
        } else {
            selectedDayLabel.text = "轻点或横向滑动图表，查看当天用量"
        }
        clearSelectionButton.isHidden = point == nil
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        navigationItem.rightBarButtonItem?.isEnabled = model.status != .loading
        if model.status != .loading { (scrollView.refreshControl as? ChargeRefreshControl)?.finish(success: model.status == .ready) }
        statusLabel.text = model.statusText
        guard let snapshot = model.snapshot else {
            chart.points = []
            [lightingTotalLabel, acTotalLabel, sharePercentLabel, dailyAverageLabel, trendLabel, peakLabel].forEach { $0.text = "—" }
            shareDetailLabel.text = "连接学校账户后查看用量"
            rangeNoteLabel.text = "暂无用量数据"
            return
        }

        let allPoints = aggregateByDay(snapshot.usageRecords)
        let current = Array(allPoints.suffix(7))
        let priorEnd = max(0, allPoints.count - current.count)
        let previous = Array(allPoints.prefix(priorEnd).suffix(7))
        chart.points = current

        let lightingTotal = current.map(\.lighting).reduce(0, +)
        let acTotal = current.map(\.airConditioning).reduce(0, +)
        let total = lightingTotal + acTotal
        let periodName = current.count == 7 ? "近 7 日" : "近 \(current.count) 日"
        lightingTotalLabel.text = String(format: "%.2f 度", lightingTotal)
        acTotalLabel.text = String(format: "%.2f 度", acTotal)
        updateTotalCardTitles(periodName: periodName)

        let dayCount = max(1, current.count)
        dailyAverageLabel.text = String(format: "%.2f 度/天", total / Double(dayCount))

        if total > 0 {
            let share = acTotal / total
            sharePercentLabel.text = String(format: "%.0f%%", share * 100)
            shareDetailLabel.text = String(format: "空调 %.2f 度 / 总计 %.2f 度", acTotal, total)
        } else {
            sharePercentLabel.text = "—"
            shareDetailLabel.text = "暂无用量"
        }

        if let peak = current.max(by: { $0.total < $1.total }) {
            peakLabel.text = "\(peak.date.formatted(.dateTime.month().day())) · \(String(format: "%.2f", peak.total)) 度"
        } else {
            peakLabel.text = "—"
        }

        let previousTotal = previous.map(\.total).reduce(0, +)
        if previous.count == current.count, previousTotal > 0 {
            let change = (total - previousTotal) / previousTotal * 100
            trendLabel.text = String(format: "%@ %.1f%%", change >= 0 ? "↑" : "↓", abs(change))
            trendLabel.textColor = change > 0 ? .systemRed : (change < 0 ? .systemGreen : .secondaryLabel)
        } else {
            trendLabel.text = "数据不足"
            trendLabel.textColor = .secondaryLabel
        }

        let containsToday = current.contains { Calendar.current.isDateInToday($0.date) }
        if containsToday {
            rangeNoteLabel.text = "今日数据截至 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) · 日均按 \(dayCount) 个自然日计算"
        } else {
            rangeNoteLabel.text = "日均按图中 \(dayCount) 个自然日计算"
        }
        let updated = "更新于 " + snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)
        switch model.status {
        case .loading: statusLabel.text = "正在更新… · " + updated
        case .authenticationRequired: statusLabel.text = "登录已过期 · 当前显示上次数据"
        case .error: statusLabel.text = "更新失败，下拉重试 · " + updated
        default: statusLabel.text = updated
        }
    }

    private func aggregateByDay(_ records: [UsageRecord]) -> [DailyUsagePoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted().map { date in
            let dayRecords = grouped[date] ?? []
            return DailyUsagePoint(
                date: date,
                lighting: dayRecords.filter { $0.kind == "照明" }.map(\.kWh).reduce(0, +),
                airConditioning: dayRecords.filter { $0.kind == "空调" }.map(\.kWh).reduce(0, +)
            )
        }
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        let refreshControl = ChargeRefreshControl()
        refreshControl.onRefresh = { [weak self] in self?.refreshPulled() }
        scrollView.refreshControl = refreshControl

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        connectScrolling(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            maxWidth
        ])

        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = UILayoutPriority(999)
        width.isActive = true

        let chartCard = PowerCardView(spacing: 10, cornerRadius: 24, contentInsets: .init(top: 16, leading: 14, bottom: 13, trailing: 14))
        chartCard.stack.addArrangedSubview(chartHeader())
        chart.translatesAutoresizingMaskIntoConstraints = false
        chartCard.stack.addArrangedSubview(chart)
        chartHeight.isActive = true
        chartCard.stack.addArrangedSubview(selectedDayLabel)
        chartCard.stack.addArrangedSubview(clearSelectionButton)
        clearSelectionButton.addAction(UIAction { [weak self] _ in self?.chart.clearSelection() }, for: .touchUpInside)
        clearSelectionButton.isHidden = true
        chartCard.stack.addArrangedSubview(rangeNoteLabel)
        stack.addArrangedSubview(chartCard)

        let lightingCard = totalCard(title: "近 7 日照明", icon: "lightbulb.fill", tint: PowerTheme.lighting, label: lightingTotalLabel)
        lightingCard.tag = 701
        let acCard = totalCard(title: "近 7 日空调", icon: "snowflake", tint: PowerTheme.cooling, label: acTotalLabel)
        acCard.tag = 702
        let totals = UIStackView(arrangedSubviews: [lightingCard, acCard])
        totals.axis = .horizontal
        totals.spacing = 12
        totals.distribution = .fillEqually
        stack.addArrangedSubview(totals)
        adaptiveRows.append(totals)

        let shareCard = PowerCardView(axis: .horizontal, spacing: 14)
        sharePercentLabel.setContentHuggingPriority(.required, for: .horizontal)
        let shareText = UIStackView(arrangedSubviews: [
            UILabel.powerLabel("近 7 日用电来自空调", style: .subheadline, weight: .semibold),
            shareDetailLabel
        ])
        shareText.axis = .vertical
        shareText.spacing = 4
        shareCard.stack.alignment = .center
        adaptiveRows.append(shareCard.stack)
        shareCard.stack.addArrangedSubview(sharePercentLabel)
        shareCard.stack.addArrangedSubview(shareText)
        stack.addArrangedSubview(shareCard)

        stack.setCustomSpacing(22, after: shareCard)
        stack.addArrangedSubview(sectionHeader("这周的用电情况", detail: "最近有记录的日期"))
        let insights = PowerCardView(spacing: 0, contentInsets: .zero)
        insights.stack.addArrangedSubview(insightRow(icon: "sum", title: "近 7 日日均", value: dailyAverageLabel, tint: PowerTheme.accent))
        insights.stack.addArrangedSubview(separator())
        insights.stack.addArrangedSubview(insightRow(icon: "chart.line.uptrend.xyaxis", title: "较前 7 日", value: trendLabel, tint: PowerTheme.accent))
        insights.stack.addArrangedSubview(separator())
        insights.stack.addArrangedSubview(insightRow(icon: "calendar.badge.clock", title: "用量最高日", value: peakLabel, tint: PowerTheme.accent))
        stack.addArrangedSubview(insights)

        statusLabel.textAlignment = .center
        stack.addArrangedSubview(statusLabel)
    }

    private func configureLegendButtons() {
        configureLegend(lightingLegend, title: "照明", color: PowerTheme.lighting, action: #selector(lightingLegendTapped))
        configureLegend(acLegend, title: "空调", color: PowerTheme.cooling, action: #selector(acLegendTapped))
        lightingLegend.isSelected = true
        acLegend.isSelected = true
        updateLegendAppearance()
    }

    private func configureLegend(_ button: UIButton, title: String, color: UIColor, action: Selector) {
        var configuration = UIButton.Configuration.glass()
        configuration.title = title
        configuration.image = UIImage(systemName: "circle.fill")
        configuration.imagePadding = 5
        configuration.preferredSymbolConfigurationForImage = .init(pointSize: 8, weight: .medium)
        configuration.baseForegroundColor = color
        configuration.baseBackgroundColor = color
        button.tintColor = color
        configuration.contentInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        button.configuration = configuration
        button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .preferredFont(forTextStyle: .caption1)
            return attributes
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityHint = "轻点切换该系列并重新缩放图表"
    }

    private func chartHeader() -> UIView {
        let title = UILabel.powerLabel("近 7 日用量", style: .headline, weight: .bold)
        let legend = UIStackView(arrangedSubviews: [lightingLegend, acLegend])
        legend.spacing = 10
        let row = UIStackView(arrangedSubviews: [title, legend])
        row.axis = .vertical
        row.alignment = .leading
        row.spacing = 4
        return row
    }

    private func updateLegendAppearance() {
        lightingLegend.configuration?.baseForegroundColor = lightingLegend.isSelected ? PowerTheme.lighting : .secondaryLabel
        acLegend.configuration?.baseForegroundColor = acLegend.isSelected ? PowerTheme.cooling : .secondaryLabel
        lightingLegend.accessibilityValue = lightingLegend.isSelected ? "已显示" : "已隐藏"
        acLegend.accessibilityValue = acLegend.isSelected ? "已显示" : "已隐藏"
    }

    @objc private func lightingLegendTapped() {
        guard !lightingLegend.isSelected || acLegend.isSelected else { return }
        lightingLegend.isSelected.toggle()
        chart.showsLighting = lightingLegend.isSelected
        updateLegendAppearance()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func acLegendTapped() {
        guard !acLegend.isSelected || lightingLegend.isSelected else { return }
        acLegend.isSelected.toggle()
        chart.showsAirConditioning = acLegend.isSelected
        updateLegendAppearance()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func updateTotalCardTitles(periodName: String) {
        for tag in [701, 702] {
            guard let card = stack.viewWithTag(tag) as? PowerCardView,
                  let header = card.stack.arrangedSubviews.first as? UIStackView,
                  let title = header.arrangedSubviews.last as? UILabel else { continue }
            title.text = "\(periodName)\(tag == 701 ? "照明" : "空调")"
        }
    }

    private func totalCard(title: String, icon: String, tint: UIColor, label: UILabel) -> PowerCardView {
        let card = PowerCardView(spacing: 10)
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = tint
        symbol.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [symbol, UILabel.powerLabel(title, style: .subheadline, weight: .semibold, color: .secondaryLabel)])
        header.spacing = 7
        header.alignment = .center
        symbol.contentMode = .scaleAspectFit
        symbol.preferredSymbolConfiguration = .init(pointSize: 18, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        card.stack.addArrangedSubview(header)
        card.stack.addArrangedSubview(label)
        return card
    }

    private func sectionHeader(_ title: String, detail: String) -> UIView {
        PowerTheme.heading(title, detail: detail)
    }

    private func insightRow(icon: String, title: String, value: UILabel, tint: UIColor) -> UIView {
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = tint
        symbol.preferredSymbolConfiguration = .init(pointSize: 17, weight: .semibold)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([symbol.widthAnchor.constraint(equalToConstant: 28), symbol.heightAnchor.constraint(equalToConstant: 28)])
        value.textAlignment = .right
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.68
        let row = UIStackView(arrangedSubviews: [symbol, UILabel.powerLabel(title, style: .subheadline, weight: .semibold), value])
        row.alignment = .center
        row.spacing = 10
        adaptiveRows.append(row)
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = .init(top: 15, leading: 16, bottom: 15, trailing: 16)
        return row
    }

    private func updateAdaptiveLayout() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        for row in adaptiveRows {
            row.axis = large ? .vertical : .horizontal
            row.alignment = large ? .leading : .center
        }
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    @objc private func refreshPulled() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        model.refresh()
    }
}
