import UIKit

/// "充多少合适？": pick an amount to see how long it lasts, or a date to see what it costs, then split it among roommates.
final class RechargePlannerViewController: UIViewController {
    private enum Mode: Int { case amount, date }
    private static let roommateKey = "rechargePlanner.roommates"
    private static let presets = [20, 50, 100, 200]

    private let planner: RechargePlanner?
    private let onRecharge: () -> Void
    private let allowsRecharge: Bool
    private var mode = Mode.amount
    private var amount: Double = 50
    private var roommates: Int {
        get { min(8, max(1, UserDefaults.standard.object(forKey: Self.roommateKey) as? Int ?? 4)) }
        set { UserDefaults.standard.set(newValue, forKey: Self.roommateKey) }
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let modePicker = UISegmentedControl(items: ["按金额", "按日期"])
    private let presetRow = UIStackView()
    private var presetButtons: [UIButton] = []
    private let customField = UITextField()
    private let datePicker = UIDatePicker()
    private let amountSection = UIStackView()
    private let dateSection = UIStackView()
    private let headline = UILabel.powerLabel(nil, style: .title1, weight: .bold, color: PowerTheme.accent)
    private let detail = UILabel.powerLabel(nil, style: .subheadline, color: .secondaryLabel)
    private let roommateLabel = UILabel.powerLabel(nil, style: .body, weight: .medium)
    private let shareLabel = UILabel.powerLabel(nil, style: .title3, weight: .bold)
    private let stepper = UIStepper()

    init(snapshot: ElectricitySnapshot?, allowsRecharge: Bool = true, onRecharge: @escaping () -> Void) {
        planner = snapshot.flatMap(RechargePlanner.init(snapshot:))
        self.allowsRecharge = allowsRecharge
        self.onRecharge = onRecharge
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "充多少合适？"
        view.backgroundColor = PowerTheme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: PowerLayout.readableWidth)
        ])
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -40)
        width.priority = UILayoutPriority(999)
        width.isActive = true

        guard let planner else {
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "function")
            empty.text = "暂时算不了"
            empty.secondaryText = "需要电价和最近的照明、空调用量。刷新电量后再试。"
            let unavailable = UIContentUnavailableView(configuration: empty)
            unavailable.heightAnchor.constraint(equalToConstant: 280).isActive = true
            stack.addArrangedSubview(unavailable)
            return
        }
        let context = UILabel.powerLabel(String(format: "现有 %.1f 度 · 近期日均 %.1f 度 · 电价 %.2f 元/度", planner.balanceKWh, planner.dailyKWh, planner.unitPrice),
                                         style: .footnote, color: .secondaryLabel)
        stack.addArrangedSubview(context)

        modePicker.selectedSegmentIndex = 0
        modePicker.addAction(UIAction { [weak self] _ in self?.modeChanged() }, for: .valueChanged)
        stack.addArrangedSubview(modePicker)

        configureAmountSection()
        configureDateSection()
        stack.addArrangedSubview(amountSection)
        stack.addArrangedSubview(dateSection)
        dateSection.isHidden = true

        let result = PowerCardView(spacing: 6, glass: true, tint: PowerTheme.hero, cornerRadius: 26, contentInsets: .init(top: 20, leading: 20, bottom: 20, trailing: 20))
        headline.numberOfLines = 0
        result.stack.addArrangedSubview(headline)
        result.stack.addArrangedSubview(detail)
        result.isAccessibilityElement = true
        stack.addArrangedSubview(result)
        resultCard = result

        stack.addArrangedSubview(roommateRow())
        let estimate = UILabel.powerLabel("按最近 7 个有记录日的平均用量估算，实际会随用电变化。", style: .caption1, color: .tertiaryLabel)
        stack.addArrangedSubview(estimate)

        let copy = PowerTheme.button("复制给室友", image: "doc.on.doc")
        copy.addAction(UIAction { [weak self] _ in self?.copySummary() }, for: .touchUpInside)
        let go = PowerTheme.button("去充值", image: "bolt.fill", primary: true)
        go.isHidden = !allowsRecharge
        go.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { self.onRecharge() }
        }, for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [copy, go])
        actions.spacing = 12
        actions.distribution = .fillEqually
        stack.setCustomSpacing(22, after: estimate)
        stack.addArrangedSubview(actions)
        update(animated: false)
    }

    private var resultCard: UIView?

    // MARK: Sections

    private func configureAmountSection() {
        amountSection.axis = .vertical
        amountSection.spacing = 10
        presetRow.spacing = 8
        presetRow.distribution = .fillEqually
        for value in Self.presets {
            var configuration = UIButton.Configuration.glass()
            configuration.title = "¥\(value)"
            configuration.cornerStyle = .capsule
            let button = PowerActionButton(configuration: configuration)
            button.tag = value
            button.addAction(UIAction { [weak self] _ in self?.pick(Double(value)) }, for: .touchUpInside)
            presetButtons.append(button)
            presetRow.addArrangedSubview(button)
        }
        amountSection.addArrangedSubview(presetRow)
        customField.placeholder = "其他金额（元）"
        customField.keyboardType = .decimalPad
        customField.borderStyle = .roundedRect
        customField.clearButtonMode = .whileEditing
        customField.font = .preferredFont(forTextStyle: .body)
        customField.adjustsFontForContentSizeCategory = true
        customField.addAction(UIAction { [weak self] _ in self?.customChanged() }, for: .editingChanged)
        amountSection.addArrangedSubview(customField)
    }

    private func configureDateSection() {
        dateSection.axis = .vertical
        dateSection.spacing = 8
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = Locale(identifier: "zh_CN")
        datePicker.minimumDate = .now
        datePicker.maximumDate = Calendar.current.date(byAdding: .day, value: 180, to: .now)
        datePicker.date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        datePicker.tintColor = PowerTheme.accent
        datePicker.addAction(UIAction { [weak self] _ in
            UISelectionFeedbackGenerator().selectionChanged()
            self?.update(animated: true)
        }, for: .valueChanged)
        dateSection.addArrangedSubview(UILabel.powerLabel("想让电用到哪一天？", style: .headline, weight: .semibold))
        dateSection.addArrangedSubview(datePicker)
    }

    private func roommateRow() -> UIView {
        stepper.minimumValue = 1
        stepper.maximumValue = 8
        stepper.value = Double(roommates)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.roommates = Int(self.stepper.value)
            UISelectionFeedbackGenerator().selectionChanged()
            self.update(animated: true)
        }, for: .valueChanged)
        let labels = UIStackView(arrangedSubviews: [roommateLabel, shareLabel])
        labels.axis = .vertical
        labels.spacing = 2
        let row = UIStackView(arrangedSubviews: [labels, stepper])
        row.alignment = .center
        row.spacing = 12
        let card = PowerCardView(spacing: 0, contentInsets: .init(top: 16, leading: 20, bottom: 16, trailing: 16))
        card.stack.addArrangedSubview(row)
        return card
    }

    // MARK: Input

    private func modeChanged() {
        mode = Mode(rawValue: modePicker.selectedSegmentIndex) ?? .amount
        view.endEditing(true)
        UISelectionFeedbackGenerator().selectionChanged()
        PowerMotion.animate {
            self.amountSection.isHidden = self.mode != .amount
            self.dateSection.isHidden = self.mode != .date
            self.amountSection.alpha = self.mode == .amount ? 1 : 0
            self.dateSection.alpha = self.mode == .date ? 1 : 0
            self.stack.layoutIfNeeded()
        }
        update(animated: true)
    }

    private func pick(_ value: Double) {
        amount = value
        customField.text = nil
        view.endEditing(true)
        update(animated: true)
    }

    private func customChanged() {
        if let value = Double(customField.text ?? ""), value > 0 { amount = min(value, 5000) }
        update(animated: true)
    }

    // MARK: Output

    /// The amount being discussed: the chosen or typed amount, or what the chosen date costs.
    private var currentAmount: Double {
        guard let planner else { return 0 }
        return mode == .amount ? amount : Double(planner.plan(until: datePicker.date).amount)
    }

    private func update(animated: Bool) {
        guard let planner else { return }
        switch mode {
        case .amount:
            let plan = planner.plan(amount: amount)
            set(headline, "约可用到 \(Self.day(plan.lastsUntil))", animated: animated)
            set(detail, String(format: "充 ¥%@ ≈ %.1f 度 · 共可用约 %.1f 天", Self.money(amount), plan.addedKWh, plan.totalDays), animated: animated)
        case .date:
            let plan = planner.plan(until: datePicker.date)
            if plan.amount == 0 {
                set(headline, "现有电量够用 🎉", animated: animated)
                set(detail, "用到 \(Self.day(datePicker.date)) 不用充，按近期用量估算", animated: animated)
            } else {
                set(headline, "至少充 ¥\(plan.amount)", animated: animated)
                set(detail, String(format: "用到 %@ 还差约 %.1f 度", Self.day(datePicker.date), plan.neededKWh), animated: animated)
            }
        }
        for button in presetButtons {
            let selected = mode == .amount && customField.text?.isEmpty != false && Double(button.tag) == amount
            var configuration: UIButton.Configuration = selected ? .prominentGlass() : .glass()
            configuration.cornerStyle = .capsule
            configuration.baseBackgroundColor = PowerTheme.accent
            // Set the title colour explicitly; glass styles otherwise tint it to match the background.
            configuration.attributedTitle = AttributedString("¥\(button.tag)", attributes: AttributeContainer([
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: selected ? UIColor.white : PowerTheme.accent
            ]))
            button.configuration = configuration
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
        roommateLabel.text = "宿舍 \(roommates) 人平摊"
        set(shareLabel, "每人 ¥\(Self.money(RechargePlanner.share(of: currentAmount, among: roommates)))", animated: animated)
        stepper.accessibilityValue = "\(roommates) 人"
        resultCard?.accessibilityLabel = "\(headline.text ?? "")。\(detail.text ?? "")"
        if animated, !UIAccessibility.isReduceMotionEnabled, let card = resultCard {
            card.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 4, options: [.allowUserInteraction]) {
                card.transform = .identity
            }
        }
    }

    private func set(_ label: UILabel, _ text: String, animated: Bool) {
        animated ? PowerMotion.replaceText(on: label, with: text) : (label.text = text)
    }

    private func copySummary() {
        let result = [headline.text, detail.text].compactMap { $0 }.joined(separator: "，")
        let share = roommates > 1 ? "，\(roommates) 人每人 ¥\(Self.money(RechargePlanner.share(of: currentAmount, among: roommates)))" : ""
        UIPasteboard.general.string = "宿舍电费：\(result)\(share)。⚡ 湖科电量"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        PowerMotion.replaceText(on: roommateLabel, with: "已复制，可以发给室友啦")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            PowerMotion.replaceText(on: self.roommateLabel, with: "宿舍 \(self.roommates) 人平摊")
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    private static func money(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
}
