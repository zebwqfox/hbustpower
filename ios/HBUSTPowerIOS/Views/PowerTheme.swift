import UIKit

/// Shared visual language. The palette comes from the selected theme (see `PowerThemeStyle`); the interface is
/// rebuilt when the theme changes, so colours captured in layers are never stale.
enum PowerTheme {
    static var style: PowerThemeStyle { PowerThemeStore.shared.style }
    static var background: UIColor { style.background }
    static var surface: UIColor { style.surface }
    static var accent: UIColor { style.accent }
    static var hero: UIColor { style.hero }
    /// Lighting figures, low-balance warnings and stickers.
    static var lighting: UIColor { style.secondary }
    /// Charging ring and sparks.
    static var spark: UIColor { style.spark }
    static var cooling: UIColor { accent }

    static func font(_ size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
    }

    static func button(_ title: String, image: String? = nil, primary: Bool = false) -> UIButton {
        var configuration = primary ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        configuration.title = title
        configuration.image = image.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = accent
        configuration.baseForegroundColor = primary ? background : accent
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(top: 15, leading: 20, bottom: 15, trailing: 20)
        let button = PowerActionButton(configuration: configuration)
        button.isPointerInteractionEnabled = true
        let foreground = primary ? PowerTheme.background : PowerTheme.accent
        button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak button] incoming in
            var attributes = incoming
            attributes.foregroundColor = foreground.withAlphaComponent(button?.isEnabled == false ? 0.5 : 1)
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        button.configuration?.imageColorTransformer = UIConfigurationColorTransformer { [weak button] _ in
            foreground.withAlphaComponent(button?.isEnabled == false ? 0.5 : 1)
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        return button
    }

    static func heading(_ title: String, detail: String? = nil) -> UIStackView {
        let titleLabel = UILabel.powerLabel(title, style: .headline, weight: .semibold)
        let stack = UIStackView(arrangedSubviews: [titleLabel])
        stack.axis = .vertical
        stack.spacing = 5
        if let detail { stack.addArrangedSubview(UILabel.powerLabel(detail, style: .subheadline, color: .secondaryLabel)) }
        return stack
    }
}

/// Drag a satellite: it follows the finger, nearby objects respond, then springs home.
final class PowerIllustrationView: UIView {
    private let disc = PowerActionButton(type: .custom)
    private let hint = UILabel.powerLabel("轻点或拖动，感受一点电力", style: .caption1, color: .secondaryLabel)
    private var tiles: [UIButton] = []
    private var restTransforms: [CGAffineTransform] = []
    private var animators: [Int: UIViewPropertyAnimator] = [:]
    private var dragOrigin = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        var discConfiguration = UIButton.Configuration.glass()
        discConfiguration.baseBackgroundColor = PowerTheme.hero
        discConfiguration.cornerStyle = .capsule
        disc.configuration = discConfiguration
        disc.layer.cornerRadius = 72
        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.accessibilityLabel = "点亮电力插画"
        disc.addTarget(self, action: #selector(energize), for: .touchUpInside)
        addSubview(disc)
        let bolt = UIImageView(image: UIImage(systemName: "bolt.fill"))
        bolt.tintColor = PowerTheme.accent
        bolt.contentMode = .scaleAspectFit
        bolt.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(bolt)
        NSLayoutConstraint.activate([
            disc.widthAnchor.constraint(equalToConstant: 144), disc.heightAnchor.constraint(equalTo: disc.widthAnchor),
            disc.centerXAnchor.constraint(equalTo: centerXAnchor), disc.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            bolt.widthAnchor.constraint(equalToConstant: 47), bolt.heightAnchor.constraint(equalToConstant: 68),
            bolt.centerXAnchor.constraint(equalTo: disc.centerXAnchor), bolt.centerYAnchor.constraint(equalTo: disc.centerYAnchor)
        ])
        for (index, item) in [
            ("lightbulb", -86.0, -59.0, -0.22, PowerTheme.lighting, "照明"),
            ("snowflake", 87.0, 32.0, 0.18, PowerTheme.cooling, "空调"),
            ("moon.stars", 60.0, -82.0, 0.12, PowerTheme.accent, "安心用电")
        ].enumerated() {
            let (symbol, x, y, angle, tint, name) = item
            // Native glass handles press deformation; the outer transform handles dragging.
            var configuration = UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: symbol)
            configuration.baseForegroundColor = tint
            configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in tint }
            configuration.preferredSymbolConfigurationForImage = .init(pointSize: 25, weight: .medium)
            configuration.cornerStyle = .fixed
            configuration.background.cornerRadius = 18
            let tile = UIButton(configuration: configuration)
            tile.layer.cornerRadius = 18
            tile.layer.cornerCurve = .continuous
            tile.translatesAutoresizingMaskIntoConstraints = false
            tile.tag = index
            tile.isPointerInteractionEnabled = true
            tile.accessibilityLabel = "\(name)互动贴纸"
            tile.accessibilityHint = "轻点让电力图标回应"
            
            tile.tintColor = tint
            
            tile.addTarget(self, action: #selector(tileTapped(_:)), for: .touchUpInside)
            tile.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
            addSubview(tile)
            let resting = CGAffineTransform(rotationAngle: angle)
            tile.transform = resting
            tiles.append(tile)
            restTransforms.append(resting)
            NSLayoutConstraint.activate([
                tile.widthAnchor.constraint(equalToConstant: 56), tile.heightAnchor.constraint(equalTo: tile.widthAnchor),
                tile.centerXAnchor.constraint(equalTo: centerXAnchor, constant: x),
                tile.centerYAnchor.constraint(equalTo: centerYAnchor, constant: y - 10)
            ])
        }
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.textAlignment = .center
        addSubview(hint)
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: leadingAnchor), hint.trailingAnchor.constraint(equalTo: trailingAnchor),
            hint.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func energize() {
        PowerMotion.replaceText(on: hint, with: "一点电力，点亮宿舍日常")
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for index in tiles.indices {
            stop(index)
            tiles[index].transform = restTransforms[index].translatedBy(x: index == 0 ? -12 : 12, y: -12)
            settle(index, velocity: .zero)
        }
    }

    @objc private func tileTapped(_ sender: UIButton) {
        PowerMotion.replaceText(on: hint, with: ["照明用量，清清楚楚", "空调用电，单独看清", "剩余电量，随时心中有数"][sender.tag])
        pulse()
        settle(sender.tag, velocity: .zero)
    }

    private func pulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        disc.transform = CGAffineTransform(scaleX: 1.065, y: 1.065)
        PowerMotion.animate(damping: 0.8) { self.disc.transform = .identity }
    }

    private func stop(_ index: Int) {
        if let animator = animators.removeValue(forKey: index) {
            if animator.state == .active {
                animator.stopAnimation(false)
                animator.finishAnimation(at: .current)
            } else if animator.state == .stopped {
                animator.finishAnimation(at: .current)
            }
        }
    }

    @objc private func dragged(_ gesture: UIPanGestureRecognizer) {
        guard let tile = gesture.view else { return }
        let index = tile.tag
        switch gesture.state {
        case .began:
            for i in tiles.indices { stop(i) }
            dragOrigin = CGPoint(x: tile.transform.tx, y: tile.transform.ty)
            bringSubviewToFront(tile)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        case .changed:
            let translation = gesture.translation(in: self)
            // Follow directly in the central region; smoothly resist beyond the artwork.
            func bounded(_ distance: CGFloat) -> CGFloat {
                let limit: CGFloat = 72
                guard abs(distance) > limit else { return distance }
                let excess = abs(distance) - limit
                return (distance < 0 ? -1 : 1) * (limit + (excess * 0.35 * limit) / (limit + excess * 0.35))
            }
            let x = bounded(dragOrigin.x + translation.x)
            let y = bounded(dragOrigin.y + translation.y)
            tile.transform = CGAffineTransform(translationX: x, y: y).concatenating(restTransforms[index])
            if !UIAccessibility.isReduceMotionEnabled {
                disc.transform = CGAffineTransform(translationX: x * 0.07, y: y * 0.07)
                for i in tiles.indices where i != index {
                    tiles[i].transform = CGAffineTransform(translationX: x * -0.08, y: y * -0.08).concatenating(restTransforms[i])
                }
            }
        case .ended, .cancelled, .failed:
            let velocity = gesture.state == .ended ? gesture.velocity(in: self) : .zero
            for i in tiles.indices { settle(i, velocity: i == index ? velocity : .zero) }
            PowerMotion.animate { self.disc.transform = .identity }
            PowerMotion.replaceText(on: hint, with: "松开，电力回到自己的位置")
        default: break
        }
    }

    private func settle(_ index: Int, velocity: CGPoint) {
        stop(index)
        let tile = tiles[index]
        if UIAccessibility.isReduceMotionEnabled {
            tile.transform = restTransforms[index]
            return
        }
        func relative(_ speed: CGFloat, _ distance: CGFloat) -> CGFloat {
            abs(distance) < 1 ? 0 : min(10, max(-10, speed / distance))
        }
        let spring = UISpringTimingParameters(dampingRatio: 0.78, initialVelocity: CGVector(
            dx: relative(velocity.x, -tile.transform.tx), dy: relative(velocity.y, -tile.transform.ty)))
        let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: spring)
        animator.addAnimations { tile.transform = self.restTransforms[index] }
        animators[index] = animator
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, self.animators[index] === animator else { return }
            self.animators.removeValue(forKey: index)
        }
        animator.startAnimation()
    }
}
