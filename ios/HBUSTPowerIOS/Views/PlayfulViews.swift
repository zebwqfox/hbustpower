import CoreMotion
import UIKit

/// Hand-made touches: slightly wobbly strokes and stickers that are not quite straight.
enum HandDrawn {
    /// A deterministic wobbly line, so the same heading always gets the same doodle.
    static func squiggle(width: CGFloat, height: CGFloat, seed: Int) -> UIBezierPath {
        let path = UIBezierPath()
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed &+ 7))
        let segments = max(3, Int(width / 22))
        path.move(to: CGPoint(x: 1, y: height * 0.6))
        for index in 1...segments {
            let x = width * CGFloat(index) / CGFloat(segments)
            let wobble = CGFloat.random(in: -0.35...0.35, using: &generator) * height
            let control = CGPoint(x: x - width / CGFloat(segments) / 2, y: (index.isMultiple(of: 2) ? height * 0.15 : height * 0.95) + wobble * 0.4)
            path.addQuadCurve(to: CGPoint(x: x - 1, y: height * 0.55 + wobble * 0.3), controlPoint: control)
        }
        return path
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return state
        }
    }
}

/// A doodled underline that draws itself the first time it appears.
final class SquiggleView: UIView {
    private let shape = CAShapeLayer()
    private let seed: Int
    private var hasDrawn = false
    var color: UIColor = PowerTheme.accent { didSet { updateColor() } }

    init(seed: Int = 1) {
        self.seed = seed
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        shape.fillColor = nil
        shape.lineWidth = 2.6
        shape.lineCap = .round
        shape.lineJoin = .round
        layer.addSublayer(shape)
        updateColor()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SquiggleView, _) in view.updateColor() }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 8) }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
        shape.path = HandDrawn.squiggle(width: bounds.width, height: bounds.height, seed: seed).cgPath
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !hasDrawn else { return }
        hasDrawn = true
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.7
        draw.beginTime = CACurrentMediaTime() + 0.25
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shape.add(draw, forKey: "draw")
    }

    private func updateColor() {
        shape.strokeColor = color.withAlphaComponent(0.55).resolvedColor(with: traitCollection).cgColor
    }
}

/// A title with a doodled underline sized to the text.
final class DoodleHeadingView: UIView {
    let titleLabel: UILabel

    init(_ title: String, detail: String? = nil, seed: Int) {
        titleLabel = UILabel.powerLabel(title, style: .title3, weight: .bold)
        super.init(frame: .zero)
        let squiggle = SquiggleView(seed: seed)
        let stack = UIStackView(arrangedSubviews: [titleLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.addArrangedSubview(squiggle)
        stack.setCustomSpacing(4, after: squiggle)
        if let detail { stack.addArrangedSubview(UILabel.powerLabel(detail, style: .subheadline, color: .secondaryLabel)) }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            squiggle.widthAnchor.constraint(equalTo: titleLabel.widthAnchor, multiplier: 0.9),
            squiggle.heightAnchor.constraint(equalToConstant: 8)
        ])
        titleLabel.accessibilityTraits = .header
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

/// A tilted label with a white border, like a sticker pressed on by hand. Tap to make it wiggle.
final class StickerView: UIControl {
    private let label = UILabel.powerLabel(nil, style: .caption1, weight: .bold, color: .white)
    private let angle: CGFloat
    var text: String? {
        get { label.text }
        set { label.text = newValue; accessibilityLabel = newValue; isHidden = newValue == nil }
    }
    var fill: UIColor = PowerTheme.accent { didSet { backgroundColor = fill } }

    init(_ text: String? = nil, angle: CGFloat = -0.08) {
        self.angle = angle
        super.init(frame: .zero)
        label.numberOfLines = 1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5), label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
        backgroundColor = fill
        layer.borderWidth = 2.5
        layer.borderColor = UIColor.white.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        transform = CGAffineTransform(rotationAngle: angle)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        self.text = text
        addTarget(self, action: #selector(wiggle), for: .touchUpInside)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    @objc func wiggle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let rest = CGAffineTransform(rotationAngle: angle)
        transform = CGAffineTransform(rotationAngle: -angle * 1.8).scaledBy(x: 1.14, y: 1.14)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.35, initialSpringVelocity: 4,
                       options: [.allowUserInteraction, .beginFromCurrentState]) { self.transform = rest }
    }
}

/// Liquid that fills the balance card: level follows the forecast, the surface tilts with the phone,
/// sloshes when touched, and can be pushed sideways with a finger.
final class EnergyLiquidView: UIView {
    private let backWave = CAShapeLayer()
    private let frontWave = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private let motion = CMMotionManager()
    private var lastTimestamp: CFTimeInterval = 0
    private var phase: CGFloat = 0
    private var shownLevel: CGFloat = 0
    private var tilt: CGFloat = 0
    private var tiltVelocity: CGFloat = 0
    private var gravityTilt: CGFloat = 0
    private var dragTilt: CGFloat = 0
    private var splash: CGFloat = 0.6

    var level: CGFloat = 0 { didSet { level = min(1, max(0, level)); if displayLink == nil { redrawStill() } } }
    var isLow = false { didSet { updateColors() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        clipsToBounds = true
        layer.addSublayer(backWave)
        layer.addSublayer(frontWave)
        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: EnergyLiquidView, _) in view.updateColors() }
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        backWave.frame = bounds
        frontWave.frame = bounds
        if displayLink == nil { redrawStill() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stop() : start()
    }

    /// A touch disturbs the surface.
    func slosh(_ strength: CGFloat = 0.7) {
        splash = min(1.4, splash + strength)
        tiltVelocity += (Bool.random() ? 1 : -1) * strength * 0.9
    }

    /// Horizontal finger offset in -1...1 pushes the liquid; pass nil when released.
    func push(_ offset: CGFloat?) {
        guard let offset else {
            dragTilt = 0
            slosh(0.5)
            return
        }
        dragTilt = max(-1, min(1, offset)) * 0.32
    }

    @objc private func reduceMotionChanged() {
        stop()
        if window != nil { start() }
    }

    private func start() {
        guard displayLink == nil else { return }
        guard !UIAccessibility.isReduceMotionEnabled else {
            shownLevel = level
            redrawStill()
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
#if DEBUG
        // Simulated gravity.x for checking tilt direction in the simulator, e.g. --liquid-gravity-x=-0.5 is tilting left.
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--liquid-gravity-x=") }),
           let gravityX = Double(argument.dropFirst("--liquid-gravity-x=".count)) {
            gravityTilt = CGFloat(max(-0.35, min(0.35, gravityX * 0.6)))
            return
        }
#endif
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 30
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let gravity = data?.gravity else { return }
                // Sensor axes only match the screen in a portrait phone layout (compact width, regular height).
                // The unfolded inner display ignores interface orientation, so regular width relies on touch alone.
                guard self.traitCollection.horizontalSizeClass == .compact, self.traitCollection.verticalSizeClass == .regular else {
                    self.gravityTilt = 0
                    return
                }
                // Keep the surface level with the ground: tilt against the phone's roll.
                self.gravityTilt = CGFloat(max(-0.35, min(0.35, gravity.x * 0.6)))
            }
        }
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        motion.stopDeviceMotionUpdates()
    }

    @objc private func step(_ link: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1 / 60 : CGFloat(min(0.05, link.timestamp - lastTimestamp))
        lastTimestamp = link.timestamp
        let target = gravityTilt + dragTilt
        tiltVelocity += ((target - tilt) * 38 - tiltVelocity * 5.5) * dt
        tilt += tiltVelocity * dt
        phase += dt * (2.1 + splash * 2)
        splash *= exp(-dt * 1.3)
        shownLevel += (level - shownLevel) * min(1, dt * 2.4)
        updatePaths(amplitude: 3.5 + splash * 9)
    }

    private func redrawStill() {
        shownLevel = level
        updatePaths(amplitude: 3)
    }

    private func updatePaths(amplitude: CGFloat) {
        guard bounds.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backWave.path = wave(amplitude: amplitude * 0.8, offset: phase * 0.8 + 1.7, raise: 5)
        frontWave.path = wave(amplitude: amplitude, offset: phase, raise: 0)
        CATransaction.commit()
    }

    private func wave(amplitude: CGFloat, offset: CGFloat, raise: CGFloat) -> CGPath {
        let width = bounds.width, height = bounds.height
        let baseline = height * (1 - shownLevel) - raise
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: height))
        for x in stride(from: 0, through: width + 4, by: 4) {
            // Positive tilt piles liquid to the right: that side rises, so its y is smaller.
            let slope = -tilt * (x - width / 2)
            let y = baseline + slope + amplitude * sin(x / width * .pi * 2.4 + offset)
            path.addLine(to: CGPoint(x: x, y: min(height, y)))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.close()
        return path.cgPath
    }

    private func updateColors() {
        let tint = (isLow ? PowerTheme.lighting : PowerTheme.accent).resolvedColor(with: traitCollection)
        backWave.fillColor = tint.withAlphaComponent(0.08).cgColor
        frontWave.fillColor = tint.withAlphaComponent(0.13).cgColor
    }
}

/// Pull to "charge". Pull past `threshold` to arm it, then let go to refresh; releasing short of it, or backing off
/// after arming, cancels. UIRefreshControl is only used to place and hold the indicator (it handles large titles);
/// its own mid-drag trigger is ignored and the owner is told through `onRefresh` on release.
final class ChargeRefreshControl: UIRefreshControl {
    private enum Phase { case idle, charging, finishing }

    var onRefresh: (() -> Void)?
    /// Called after a successful refresh has been shown, e.g. to slosh the balance card.
    var onFinished: (() -> Void)?

    private let threshold: CGFloat = 96
    private let row = UIStackView()
    private let ringHost = UIView()
    private let track = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let sparks = CAEmitterLayer()
    private let bolt = UIImageView(image: UIImage(systemName: "bolt.fill"))
    private let check = UIImageView(image: UIImage(systemName: "checkmark"))
    private let caption = UILabel.powerLabel(nil, style: .footnote, weight: .semibold, color: .secondaryLabel)
    private var offsetObservation: NSKeyValueObservation?
    private weak var observedScrollView: UIScrollView?
    private var wasTracking = false
    private var phase = Phase.idle
    private var armed = false
    private var baselineTop: CGFloat?
    private var chargingStartedAt: CFTimeInterval = 0
    private var pendingFinish = false
    private var captionTimer: Timer?
    private static let minimumChargingTime: CFTimeInterval = 0.8
    /// The theme's spark colour, always bright enough to read as "electric".
    private static var electric: UIColor { PowerTheme.spark }
    private static var chargingLines: [String] {
        ["正在连接宿舍电表…", "滋滋滋，数据充电中…", "去学校系统看一眼…", PowerTheme.style.chargingLine]
    }

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    override init() {
        super.init()
        tintColor = .clear
        ringHost.translatesAutoresizingMaskIntoConstraints = false
        for shape in [track, ring] {
            shape.fillColor = nil
            shape.lineWidth = 3.5
            shape.lineCap = .round
            shape.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
            let rect = shape.bounds.insetBy(dx: 1.75, dy: 1.75)
            shape.path = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                                      startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true).cgPath
            ringHost.layer.addSublayer(shape)
        }
        ring.shadowOffset = .zero
        ring.shadowRadius = 6
        sparks.emitterShape = .circle
        sparks.emitterMode = .outline
        sparks.emitterPosition = CGPoint(x: 17, y: 17)
        sparks.emitterSize = CGSize(width: 34, height: 34)
        sparks.birthRate = 0
        ringHost.layer.addSublayer(sparks)
        for symbol in [bolt, check] {
            symbol.contentMode = .scaleAspectFit
            symbol.translatesAutoresizingMaskIntoConstraints = false
            ringHost.addSubview(symbol)
        }
        check.preferredSymbolConfiguration = .init(pointSize: 15, weight: .heavy)
        check.alpha = 0
        caption.numberOfLines = 1
        row.addArrangedSubview(ringHost)
        row.addArrangedSubview(caption)
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor), row.centerYAnchor.constraint(equalTo: centerYAnchor),
            ringHost.widthAnchor.constraint(equalToConstant: 34), ringHost.heightAnchor.constraint(equalToConstant: 34),
            bolt.centerXAnchor.constraint(equalTo: ringHost.centerXAnchor), bolt.centerYAnchor.constraint(equalTo: ringHost.centerYAnchor),
            bolt.widthAnchor.constraint(equalToConstant: 14), bolt.heightAnchor.constraint(equalToConstant: 17),
            check.centerXAnchor.constraint(equalTo: ringHost.centerXAnchor), check.centerYAnchor.constraint(equalTo: ringHost.centerYAnchor)
        ])
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (control: ChargeRefreshControl, _) in control.applyColors(animated: false) }
        applyColors(animated: false)
        showPull(0)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// UIKit may re-parent the control inside the scroll view, so look up the chain rather than at `superview`.
    private var scrollView: UIScrollView? {
        var view = superview
        while let current = view, !(current is UIScrollView) { view = current.superview }
        return view as? UIScrollView
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let scrollView, scrollView !== observedScrollView else { return }
        observedScrollView = scrollView
        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            MainActor.assumeIsolated { self?.scrolled(scrollView) }
        }
    }

    /// Kept for callers that simply end refreshing; treated as success.
    override func endRefreshing() { finish(success: true) }

    /// Shows the outcome, then collapses. Safe to call repeatedly or while nothing is refreshing.
    func finish(success: Bool) {
        guard phase == .charging else {
            // UIKit may have opened the control mid-drag; only close it once the finger is up.
            if phase == .idle, isRefreshing, scrollView?.isTracking != true { super.endRefreshing() }
            return
        }
        guard !pendingFinish else { return }
        pendingFinish = true
        let wait = reduceMotion ? 0 : max(0, Self.minimumChargingTime - (CACurrentMediaTime() - chargingStartedAt))
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self else { return }
            success ? self.showSuccess() : self.showFailure()
            DispatchQueue.main.asyncAfter(deadline: .now() + (self.reduceMotion ? 0.3 : 0.75)) { [weak self] in self?.collapse(success: success) }
        }
    }

    // MARK: Pulling

    /// The finger lifted: charge if armed, otherwise quietly undo any refresh UIKit started on its own.
    private func released() {
        if armed {
            startCharging()
        } else {
            // Let the scroll view finish handling the release first; UIKit ignores ending a refresh mid-gesture.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase == .idle else { return }
                self.cancelSystemRefresh()
            }
        }
    }

    /// UIKit may start its own refresh mid-drag at a shorter distance; close it without telling the owner.
    private func cancelSystemRefresh() {
        guard isRefreshing else { return }
        super.endRefreshing()
        if let scrollView, let top = baselineTop, scrollView.contentOffset.y < -top {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -top), animated: true)
        }
    }

    private func scrolled(_ scrollView: UIScrollView) {
        let tracking = scrollView.isTracking
        defer { wasTracking = tracking }
        guard phase == .idle else { return }
        if tracking, !wasTracking, !isRefreshing { baselineTop = scrollView.adjustedContentInset.top }
        if !tracking, wasTracking { released() }
        guard phase == .idle else { return }
        let top = baselineTop ?? scrollView.adjustedContentInset.top
        let pull = -(scrollView.contentOffset.y + top)
        if pull <= 0, !scrollView.isTracking { baselineTop = nil }
        showPull(pull / threshold)
        guard scrollView.isTracking else { return }
        if pull >= threshold, !armed { arm() } else if pull < threshold * 0.9, armed { disarm() }
    }

    private func showPull(_ raw: CGFloat) {
        let progress = min(1, max(0, raw))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeEnd = progress
        CATransaction.commit()
        row.alpha = min(1, progress * 1.6)
        guard !armed else { return }
        bolt.alpha = 0.35 + progress * 0.65
        caption.text = progress < 0.05 ? nil : "继续下拉，给数据充电"
        guard !reduceMotion else { return }
        // The bolt grows and rises as the ring fills; past the threshold the whole row stretches a little.
        let scale = 0.6 + progress * 0.4
        bolt.transform = CGAffineTransform(translationX: 0, y: (1 - progress) * 6).scaledBy(x: scale, y: scale)
        let stretch = 1 + min(0.12, max(0, raw - 1) * 0.3)
        ringHost.transform = CGAffineTransform(scaleX: stretch, y: stretch)
    }

    private func arm() {
        armed = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        PowerMotion.replaceText(on: caption, with: "松手，开始充电 ⚡")
        applyColors(animated: true)
        bolt.alpha = 1
        guard !reduceMotion else { return }
        bolt.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 6, options: [.allowUserInteraction]) {
            self.bolt.transform = .identity
        }
        burst(count: 10, colors: [Self.electric, PowerTheme.accent])
    }

    private func disarm() {
        armed = false
        UISelectionFeedbackGenerator().selectionChanged()
        applyColors(animated: true)
        PowerMotion.replaceText(on: caption, with: "继续下拉，给数据充电")
    }

    // MARK: Charging

    private func startCharging() {
        armed = false
        phase = .charging
        chargingStartedAt = CACurrentMediaTime()
        if !isRefreshing { beginRefreshing() }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        row.alpha = 1
        ringHost.transform = .identity
        applyColors(animated: false, charging: true)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeEnd = 0.3
        CATransaction.commit()
        cycleCaption()
        onRefresh?()
        guard !reduceMotion else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.byValue = CGFloat.pi * 2
        spin.duration = 0.8
        spin.repeatCount = .infinity
        ring.add(spin, forKey: "spin")
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.82
        pulse.toValue = 1.18
        pulse.duration = 0.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        bolt.layer.add(pulse, forKey: "pulse")
        let glow = CABasicAnimation(keyPath: "shadowOpacity")
        glow.fromValue = 0.15
        glow.toValue = 0.9
        glow.duration = 0.6
        glow.autoreverses = true
        glow.repeatCount = .infinity
        ring.add(glow, forKey: "glow")
        sparks.emitterCells = [sparkCell(color: Self.electric, birthRate: 7)]
        sparks.beginTime = CACurrentMediaTime()
        sparks.birthRate = 1
    }

    private func cycleCaption() {
        captionTimer?.invalidate()
        var index = Int.random(in: 0..<Self.chargingLines.count)
        caption.text = Self.chargingLines[index]
        captionTimer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.phase == .charging else { return }
                index = (index + 1) % Self.chargingLines.count
                PowerMotion.replaceText(on: self.caption, with: Self.chargingLines[index])
            }
        }
    }

    private func stopChargingEffects() {
        captionTimer?.invalidate()
        ring.removeAnimation(forKey: "spin")
        ring.removeAnimation(forKey: "glow")
        bolt.layer.removeAnimation(forKey: "pulse")
        sparks.birthRate = 0
    }

    // MARK: Outcome

    private func showSuccess() {
        phase = .finishing
        stopChargingEffects()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let green = UIColor.systemGreen.resolvedColor(with: traitCollection)
        let fill = CABasicAnimation(keyPath: "strokeEnd")
        fill.fromValue = ring.presentation()?.strokeEnd ?? ring.strokeEnd
        fill.toValue = 1
        fill.duration = reduceMotion ? 0 : 0.3
        ring.strokeEnd = 1
        ring.add(fill, forKey: "fill")
        ring.strokeColor = green.cgColor
        ring.shadowColor = green.cgColor
        check.tintColor = green
        PowerMotion.replaceText(on: caption, with: "充满啦！")
        caption.textColor = green
        guard !reduceMotion else {
            bolt.alpha = 0
            check.alpha = 1
            return
        }
        check.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        UIView.animate(withDuration: 0.15) { self.bolt.alpha = 0; self.bolt.transform = CGAffineTransform(scaleX: 0.3, y: 0.3) }
        UIView.animate(withDuration: 0.5, delay: 0.08, usingSpringWithDamping: 0.45, initialSpringVelocity: 8, options: []) {
            self.check.alpha = 1
            self.check.transform = .identity
        }
        burst(count: 18, colors: [UIColor.systemGreen, Self.electric, PowerTheme.accent])
        onFinished?()
    }

    private func showFailure() {
        phase = .finishing
        stopChargingEffects()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let orange = UIColor.systemOrange.resolvedColor(with: traitCollection)
        ring.strokeColor = orange.cgColor
        ring.shadowOpacity = 0
        bolt.tintColor = orange
        caption.textColor = orange
        PowerMotion.replaceText(on: caption, with: "没充上电，稍后再试")
        guard !reduceMotion else { return }
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -6, 6, -4, 4, -2, 0]
        shake.duration = 0.45
        ringHost.layer.add(shake, forKey: "shake")
    }

    private func collapse(success: Bool) {
        super.endRefreshing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.reset() }
    }

    private func reset() {
        phase = .idle
        pendingFinish = false
        armed = false
        baselineTop = nil
        ring.removeAllAnimations()
        bolt.transform = .identity
        check.alpha = 0
        check.transform = .identity
        caption.textColor = .secondaryLabel
        applyColors(animated: false)
        showPull(0)
    }

    // MARK: Look

    private func applyColors(animated: Bool, charging: Bool = false) {
        let hot = armed || charging
        let color = (hot ? Self.electric : PowerTheme.accent).resolvedColor(with: traitCollection)
        let changes = {
            self.track.strokeColor = PowerTheme.accent.resolvedColor(with: self.traitCollection).withAlphaComponent(0.15).cgColor
            self.ring.strokeColor = color.cgColor
            self.ring.shadowColor = color.cgColor
            self.ring.shadowOpacity = hot ? 0.7 : 0
            self.bolt.tintColor = color
        }
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            changes()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            changes()
            CATransaction.commit()
        }
    }

    private func burst(count: Float, colors: [UIColor]) {
        guard !reduceMotion else { return }
        sparks.emitterCells = colors.map { sparkCell(color: $0, birthRate: count / Float(colors.count) * 12) }
        sparks.beginTime = CACurrentMediaTime()
        sparks.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.phase != .charging else { return }
            self.sparks.birthRate = 0
        }
    }

    private func sparkCell(color: UIColor, birthRate: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = Self.dot
        cell.color = color.resolvedColor(with: traitCollection).cgColor
        cell.birthRate = birthRate
        cell.lifetime = 0.6
        cell.lifetimeRange = 0.2
        cell.velocity = 60
        cell.velocityRange = 30
        cell.emissionRange = .pi * 2
        cell.scale = 0.3
        cell.scaleRange = 0.15
        cell.scaleSpeed = -0.6
        cell.alphaSpeed = -1.4
        return cell
    }

    private static let dot: CGImage? = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
    }.cgImage
}

/// Renders a shareable balance card without relying on on-screen glass effects.
enum ShareCardRenderer {
    static func image(room: String, balance: Double, forecast: String, isLow: Bool, traits: UITraitCollection) -> UIImage {
        let size = CGSize(width: 900, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let light = traits.modifyingTraits { $0.userInterfaceStyle = .light }
        let accent = PowerTheme.accent.resolvedColor(with: light)
        let tint = (isLow ? PowerTheme.lighting : PowerTheme.accent).resolvedColor(with: light)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            PowerTheme.hero.resolvedColor(with: light).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            tint.withAlphaComponent(0.13).setFill()
            let liquid = UIBezierPath()
            let level = size.height * 0.52
            liquid.move(to: CGPoint(x: 0, y: size.height))
            for x in stride(from: CGFloat(0), through: size.width, by: 10) {
                liquid.addLine(to: CGPoint(x: x, y: level + 14 * sin(x / size.width * .pi * 2.4)))
            }
            liquid.addLine(to: CGPoint(x: size.width, y: size.height))
            liquid.fill()
            accent.withAlphaComponent(0.5).setStroke()
            let doodle = HandDrawn.squiggle(width: 260, height: 14, seed: 42)
            doodle.apply(CGAffineTransform(translationX: 64, y: 138))
            doodle.lineWidth = 5
            doodle.lineCapStyle = .round
            doodle.stroke()
            func draw(_ text: String, _ font: UIFont, _ color: UIColor, at point: CGPoint) {
                (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
            }
            draw(room, .systemFont(ofSize: 44, weight: .semibold), accent, at: CGPoint(x: 64, y: 70))
            draw(String(format: "%.2f", balance), .systemFont(ofSize: 150, weight: .medium), accent, at: CGPoint(x: 56, y: 170))
            draw("度", .systemFont(ofSize: 48, weight: .regular), accent, at: CGPoint(x: 64 + (String(format: "%.2f", balance) as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 150, weight: .medium)]).width, y: 262))
            draw(forecast, .systemFont(ofSize: 38, weight: .medium), tint, at: CGPoint(x: 64, y: 370))
            draw("⚡ 湖科电量", .systemFont(ofSize: 30, weight: .semibold), accent.withAlphaComponent(0.7), at: CGPoint(x: 64, y: 510))
        }
    }
}

/// Attaches a long-press menu built on demand; keeps itself alive for as long as the view does.
final class MenuAttachment: NSObject, UIContextMenuInteractionDelegate {
    private let menu: () -> UIMenu?
    private static var key: UInt8 = 0

    private init(_ menu: @escaping () -> UIMenu?) { self.menu = menu }

    static func attach(to view: UIView, _ menu: @escaping () -> UIMenu?) {
        let attachment = MenuAttachment(menu)
        objc_setAssociatedObject(view, &key, attachment, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        view.addInteraction(UIContextMenuInteraction(delegate: attachment))
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let menu = menu() else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu }
    }
}

/// A line from Stray Birds with its attribution, shown in the 紫鸟紫 theme. Tap for the next one.
final class StrayBirdsCardView: PowerInteractiveControl {
    private let quote = UILabel.powerLabel(StrayBirds.ofThisLaunch, style: .subheadline, weight: .medium)
    private let source = UILabel.powerLabel("—— " + StrayBirds.attribution, style: .caption1, color: .secondaryLabel)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = PowerTheme.hero
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        quote.numberOfLines = 0
        quote.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .italicSystemFont(ofSize: 16))
        source.textAlignment = .right
        let bird = UIImageView(image: UIImage(systemName: "bird.fill"))
        bird.tintColor = PowerTheme.accent
        bird.preferredSymbolConfiguration = .init(pointSize: 15, weight: .semibold)
        bird.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [bird, UILabel.powerLabel("今天的一句", style: .caption1, weight: .semibold, color: PowerTheme.accent), UIView()])
        header.spacing = 6
        header.alignment = .center
        let stack = UIStackView(arrangedSubviews: [header, quote, source])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(10, after: header)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        addTarget(self, action: #selector(nextLine), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "轻点换一句"
        updateAccessibility()
        MenuAttachment.attach(to: self) { [weak self] in
            guard let text = self?.quote.text else { return nil }
            return UIMenu(children: [UIAction(title: "复制这句", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = "\(text)\n—— \(StrayBirds.attribution)"
            }])
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func nextLine() {
        UISelectionFeedbackGenerator().selectionChanged()
        PowerMotion.replaceText(on: quote, with: StrayBirds.line(after: quote.text ?? ""))
        updateAccessibility()
    }

    private func updateAccessibility() {
        accessibilityLabel = "\(quote.text ?? "")，\(StrayBirds.attribution)"
    }
}
