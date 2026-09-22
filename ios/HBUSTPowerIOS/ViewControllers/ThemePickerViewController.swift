import UIKit

/// Pick a colour scheme. Tapping the current one again plays its signature little animation.
final class ThemePickerViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var cards: [PowerThemeStyle: ThemeCardView] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "主题"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = PowerTheme.background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        setContentScrollView(scrollView, for: .all)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: PowerLayout.readableWidth)
        ])
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = UILayoutPriority(999)
        width.isActive = true

        stack.addArrangedSubview(DoodleHeadingView("换个颜色", detail: "选中的主题再点一下，会有小动静", seed: 27))
        for style in PowerThemeStyle.allCases {
            let card = ThemeCardView(style: style)
            card.addAction(UIAction { [weak self] _ in self?.choose(style) }, for: .touchUpInside)
            cards[style] = card
            stack.addArrangedSubview(card)
        }
        let note = UILabel.powerLabel("主题只改变颜色和一点小彩蛋，数据和功能完全一样。", style: .caption1, color: .tertiaryLabel)
        stack.setCustomSpacing(22, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(note)
        updateSelection()
    }

    private func choose(_ style: PowerThemeStyle) {
        guard style != PowerThemeStore.shared.style else {
            cards[style]?.playSignature()
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        PowerThemeStore.shared.select(style)
        updateSelection()
        cards[style]?.playSignature()
    }

    private func updateSelection() {
        let current = PowerThemeStore.shared.style
        for (style, card) in cards { card.isChosen = style == current }
    }
}

private final class ThemeCardView: PowerInteractiveControl {
    private let style: PowerThemeStyle
    private let symbol = UIImageView()
    private let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let greeting = UILabel.powerLabel(nil, style: .footnote, weight: .semibold)
    private let swatches = UIStackView()

    var isChosen = false {
        didSet {
            check.isHidden = !isChosen
            layer.borderWidth = isChosen ? 2 : 0
            accessibilityTraits = isChosen ? [.button, .selected] : .button
        }
    }

    init(style: PowerThemeStyle) {
        self.style = style
        super.init(frame: .zero)
        backgroundColor = style.hero
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderColor = style.accent.cgColor
        symbol.image = UIImage(systemName: style.symbol)
        symbol.tintColor = style.accent
        symbol.preferredSymbolConfiguration = .init(pointSize: 24, weight: .semibold)
        symbol.setContentHuggingPriority(.required, for: .horizontal)
        check.tintColor = style.accent
        check.preferredSymbolConfiguration = .init(pointSize: 22, weight: .semibold)
        check.setContentHuggingPriority(.required, for: .horizontal)
        check.isHidden = true
        let name = UILabel.powerLabel(style.name, style: .headline, weight: .bold, color: style.accent)
        let tagline = UILabel.powerLabel(style.tagline, style: .subheadline, color: .secondaryLabel)
        tagline.numberOfLines = 0
        for color in [style.accent, style.secondary, style.spark, style.surface] {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 7
            dot.layer.borderWidth = 0.5
            dot.layer.borderColor = UIColor.separator.cgColor
            dot.widthAnchor.constraint(equalToConstant: 14).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 14).isActive = true
            swatches.addArrangedSubview(dot)
        }
        swatches.spacing = 6
        swatches.addArrangedSubview(UIView())
        greeting.textColor = style.accent
        greeting.alpha = 0
        let header = UIStackView(arrangedSubviews: [symbol, name, UIView(), check])
        header.spacing = 10
        header.alignment = .center
        let labels = UIStackView(arrangedSubviews: [header, tagline])
        labels.axis = .vertical
        labels.spacing = 4
        if let credit = style.credit {
            labels.addArrangedSubview(UILabel.powerLabel(credit, style: .caption1, color: .tertiaryLabel))
        }
        labels.addArrangedSubview(swatches)
        labels.setCustomSpacing(12, after: labels.arrangedSubviews[labels.arrangedSubviews.count - 2])
        labels.addArrangedSubview(greeting)
        labels.isUserInteractionEnabled = false
        labels.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labels)
        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            labels.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            labels.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            labels.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "\(style.name)主题，\(style.tagline)"
        accessibilityHint = "轻点使用，再次轻点查看主题动效"
        accessibilityTraits = .button
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Each theme greets you differently: a bolt pulse, stars for the night fur, a swinging bell for the collar.
    func playSignature() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        PowerMotion.replaceText(on: greeting, with: style.greeting)
        PowerMotion.animate { self.greeting.alpha = 1 }
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        switch style {
        case .classic:
            symbol.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 6, options: []) {
                self.symbol.transform = .identity
            }
        case .purpleBird:
            let twinkle = CAKeyframeAnimation(keyPath: "opacity")
            twinkle.values = [1, 0.25, 1, 0.4, 1]
            twinkle.duration = 0.9
            symbol.layer.add(twinkle, forKey: "twinkle")
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 8
            rise.toValue = 0
            rise.duration = 0.5
            symbol.layer.add(rise, forKey: "rise")
        case .mapleYellow:
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            swing.values = [0, 0.45, -0.35, 0.22, -0.12, 0]
            swing.duration = 0.8
            symbol.layer.add(swing, forKey: "swing")
        }
    }
}
