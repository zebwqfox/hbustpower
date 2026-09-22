import UIKit

final class PowerCardView: UIView {
    let stack = UIStackView()
    private let glassView: UIVisualEffectView?

    init(
        axis: NSLayoutConstraint.Axis = .vertical,
        spacing: CGFloat = 8,
        glass: Bool = false,
        tint: UIColor? = nil,
        cornerRadius: CGFloat = 22,
        contentInsets: NSDirectionalEdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) {
        if glass {
            let effect = UIGlassEffect()
            effect.tintColor = tint
            effect.isInteractive = false
            glassView = UIVisualEffectView(effect: effect)
        } else {
            glassView = nil
        }
        super.init(frame: .zero)
        backgroundColor = glass ? .clear : PowerTheme.surface
        if !glass {
            layer.cornerRadius = cornerRadius
            layer.cornerCurve = .continuous
        }
        stack.axis = axis
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let contentHost: UIView
        if let glassView {
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.cornerConfiguration = .uniformCorners(radius: .fixed(cornerRadius))
            addSubview(glassView)
            NSLayoutConstraint.activate([
                glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
                glassView.topAnchor.constraint(equalTo: topAnchor),
                glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            contentHost = glassView.contentView
        } else {
            contentHost = self
        }
        contentHost.directionalLayoutMargins = contentInsets
        contentHost.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentHost.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentHost.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentHost.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentHost.layoutMarginsGuide.bottomAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

final class PowerBackdropView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(gradient)
        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PowerBackdropView, _) in
            view.updateColors()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    private func updateColors() {
        backgroundColor = PowerTheme.background
        gradient.colors = [PowerTheme.background.resolvedColor(with: traitCollection).cgColor,
                           PowerTheme.background.resolvedColor(with: traitCollection).cgColor]
    }

}

/// Adaptive layout decisions, made from size classes rather than screen sizes or orientation,
/// as Apple recommends for iPhone Duo: the outer display is compact width, the inner display and iPad are regular.
enum PowerLayout {
    static let readableWidth: CGFloat = 620
    static let wideWidth: CGFloat = 980
    static let traits: [UITrait] = [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    /// Room for two columns: the unfolded inner display, iPad, and wide multitasking windows.
    static func isWide(_ traits: UITraitCollection) -> Bool { traits.horizontalSizeClass == .regular }
    /// Little height: phone-sized windows in landscape.
    static func isShort(_ traits: UITraitCollection) -> Bool { traits.verticalSizeClass == .compact }
}

extension UILabel {
    static func powerLabel(_ text: String? = nil, style: UIFont.TextStyle, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize, weight: weight))
        label.textColor = color
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }
}

class ModelViewController: UIViewController {
    let model: AppModel
    private var observer: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        observer = NotificationCenter.default.addObserver(forName: .powerModelDidChange, object: model, queue: .main) { [weak self] _ in
            self?.modelDidChange()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func modelDidChange() {}

    /// A standard item with a title and symbol, so the system can move it into the vertical bar on iPhone Duo.
    func installRefreshButton() {
        let item = UIBarButtonItem(title: "刷新", image: UIImage(systemName: "arrow.clockwise"),
                                   primaryAction: UIAction { [weak self] _ in self?.refreshTapped() })
        item.accessibilityLabel = "刷新数据"
        navigationItem.rightBarButtonItem = item
    }

    /// Decorative views must not intercept UIKit's primary-scroll-view discovery.
    func connectScrolling(_ scrollView: UIScrollView) {
        if let backdrop = view.subviews.first(where: { $0 is PowerBackdropView }) {
            backdrop.removeFromSuperview()
        }
        view.sendSubviewToBack(scrollView)
        scrollView.contentInsetAdjustmentBehavior = .automatic
        setContentScrollView(scrollView, for: .all)
    }

    func installBackdrop() {
        let backdrop = PowerBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func refreshTapped() { model.refresh() }

    func presentLoginIfNeeded() {
        guard model.status == .authenticationRequired, presentedViewController == nil, viewIfLoaded?.window != nil else { return }
        let auth = AuthenticationViewController(model: model)
        present(UINavigationController(rootViewController: auth), animated: true)
    }
}
