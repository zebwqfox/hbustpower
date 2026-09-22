import UIKit

/// Everything personal about the app lives here, so it is easy to rewrite in your own words.
enum DeveloperProfile {
    static let name = "中二"
    /// Bundled in the asset catalog so the About page works offline. Source: cdn-imfurry.imfurry.com/avatar/zebwqFurryAvatar.png
    static let avatarImageName = "DeveloperAvatar"
    static let tagline = "一个人写的宿舍电量小工具"
    static let note = """
    做这个 App，是因为每次想看宿舍还剩多少电，都要在智慧湖科里点好几层。

    所以我把最常看的东西放到了第一屏：还剩多少、还能用多久。数据都直接来自学校官方系统，账号密码不会经过我，也不会保存在任何服务器上。

    它还有很多不完美的地方。如果哪里不好用，或者学校页面改版导致读不出数据，欢迎告诉我。
    """
    /// Set to a mailto:, QQ group or issue page link to show a feedback button.
    static let feedbackURL: URL? = nil
    static let footer = "Made with ⚡ & ☕ · 湖北科技学院"
}

final class AboutViewController: ModelViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let avatar = DeveloperAvatarView(name: DeveloperProfile.name, imageName: DeveloperProfile.avatarImageName)
    private let taglineLabel = UILabel.powerLabel(DeveloperProfile.tagline, style: .subheadline, color: .secondaryLabel)
    private var avatarTaps = 0
    private let replies = ["你好呀 👋", "别戳啦，痒", "今天记得关空调", "再点几下试试？", "快到了…", "就差一下！"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "关于"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        connectScrolling(scrollView)
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 620)
        ])
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = UILayoutPriority(999)
        width.isActive = true

        stack.addArrangedSubview(header())
        stack.setCustomSpacing(34, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(DoodleHeadingView("开发者的话", seed: 5))
        stack.addArrangedSubview(PaperNoteView(text: DeveloperProfile.note, signature: "— " + DeveloperProfile.name))
        stack.setCustomSpacing(34, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(DoodleHeadingView("最近更新", detail: "轻点展开看看这一版改了什么", seed: 9))
        let timeline = UIStackView()
        timeline.axis = .vertical
        let recent = Changelog.releases.prefix(3)
        for (index, release) in recent.enumerated() {
            timeline.addArrangedSubview(ReleaseRowView(release: release, isLatest: index == 0, isLast: index == recent.count - 1) { [weak self] in
                PowerMotion.animate { self?.view.layoutIfNeeded() }
            })
        }
        stack.addArrangedSubview(timeline)
        let allReleases = PowerTheme.button("查看全部 \(Changelog.releases.count) 个版本的更新日志", image: "list.bullet.rectangle")
        allReleases.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(ChangelogViewController(), animated: true)
        }, for: .touchUpInside)
        stack.addArrangedSubview(allReleases)
        stack.setCustomSpacing(28, after: allReleases)
        if let url = DeveloperProfile.feedbackURL {
            let feedback = PowerTheme.button("给开发者反馈", image: "bubble.left.and.text.bubble.right", primary: true)
            feedback.addAction(UIAction { _ in UIApplication.shared.open(url) }, for: .touchUpInside)
            stack.addArrangedSubview(feedback)
        }
        let diagnostics = PowerTheme.button("遇到问题？看看诊断信息", image: "stethoscope")
        diagnostics.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(DebugViewController(model: self.model), animated: true)
        }, for: .touchUpInside)
        stack.addArrangedSubview(diagnostics)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let footer = UILabel.powerLabel("\(DeveloperProfile.footer)\n版本 \(version)（\(build)）", style: .caption1, color: .tertiaryLabel)
        footer.textAlignment = .center
        stack.setCustomSpacing(30, after: diagnostics)
        stack.addArrangedSubview(footer)
    }

    private func header() -> UIView {
        let nameLabel = UILabel.powerLabel(DeveloperProfile.name, style: .title1, weight: .bold)
        nameLabel.textAlignment = .center
        taglineLabel.textAlignment = .center
        avatar.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        let badge = StickerView("独立开发", angle: 0.14)
        badge.translatesAutoresizingMaskIntoConstraints = false
        let avatarHost = UIView()
        avatarHost.addSubview(avatar)
        avatarHost.addSubview(badge)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarHost.heightAnchor.constraint(equalToConstant: 112),
            avatar.widthAnchor.constraint(equalToConstant: 104), avatar.heightAnchor.constraint(equalToConstant: 104),
            avatar.centerXAnchor.constraint(equalTo: avatarHost.centerXAnchor), avatar.topAnchor.constraint(equalTo: avatarHost.topAnchor),
            badge.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: -26), badge.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 4)
        ])
        let squiggle = SquiggleView(seed: 21)
        let squiggleHost = UIView()
        squiggle.translatesAutoresizingMaskIntoConstraints = false
        squiggleHost.addSubview(squiggle)
        // Hug the name so the underline can follow the text rather than the full row.
        let nameHost = UIStackView(arrangedSubviews: [nameLabel])
        nameHost.axis = .vertical
        nameHost.alignment = .center
        let header = UIStackView(arrangedSubviews: [avatarHost, nameHost, squiggleHost, taglineLabel])
        header.axis = .vertical
        header.spacing = 6
        header.setCustomSpacing(16, after: avatarHost)
        header.setCustomSpacing(8, after: squiggleHost)
        // The underline follows the name's width, so it needs both in the same hierarchy first.
        NSLayoutConstraint.activate([
            squiggleHost.heightAnchor.constraint(equalToConstant: 8),
            squiggle.centerXAnchor.constraint(equalTo: squiggleHost.centerXAnchor), squiggle.topAnchor.constraint(equalTo: squiggleHost.topAnchor),
            squiggle.heightAnchor.constraint(equalToConstant: 8), squiggle.widthAnchor.constraint(equalTo: nameLabel.widthAnchor, multiplier: 1.35)
        ])
        return header
    }

    @objc private func avatarTapped() {
        avatarTaps += 1
        if avatarTaps == 7 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            PowerMotion.replaceText(on: taglineLabel, with: "⚡ 你找到彩蛋了！谢谢你这么认真地用它")
            avatar.burst()
            return
        }
        avatar.wiggle()
        PowerMotion.replaceText(on: taglineLabel, with: avatarTaps > 7 ? "彩蛋只有一个啦 😄" : replies[(avatarTaps - 1) % replies.count])
    }
}

/// The developer's avatar with a slightly off-centre doodled ring.
private final class DeveloperAvatarView: PowerInteractiveControl {
    private let ring = CAShapeLayer()
    private let emitter = CAEmitterLayer()

    private let photo = UIImageView()

    init(name: String, imageName: String) {
        super.init(frame: .zero)
        // Only the photo is clipped to a circle; the doodled ring and the easter-egg burst draw outside it.
        photo.image = UIImage(named: imageName)
        photo.contentMode = .scaleAspectFill
        photo.clipsToBounds = true
        photo.backgroundColor = PowerTheme.hero
        photo.isUserInteractionEnabled = false
        photo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(photo)
        NSLayoutConstraint.activate([
            photo.leadingAnchor.constraint(equalTo: leadingAnchor), photo.trailingAnchor.constraint(equalTo: trailingAnchor),
            photo.topAnchor.constraint(equalTo: topAnchor), photo.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        ring.fillColor = nil
        ring.lineWidth = 2.5
        ring.lineCap = .round
        layer.addSublayer(ring)
        layer.addSublayer(emitter)
        isAccessibilityElement = true
        accessibilityLabel = "\(name)的头像"
        accessibilityHint = "轻点打个招呼"
        accessibilityTraits = .button
        updateRingColor()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: DeveloperAvatarView, _) in view.updateRingColor() }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        photo.layer.cornerRadius = bounds.width / 2
        // Two loose, slightly different circles, like a ring drawn in one quick stroke.
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath()
        for turn in 0..<2 {
            let radius = bounds.width / 2 + 7 + CGFloat(turn) * 2.5
            let start = -0.4 + CGFloat(turn) * 2.9
            path.move(to: CGPoint(x: center.x + radius * cos(start), y: center.y + radius * sin(start)))
            path.addArc(withCenter: CGPoint(x: center.x + CGFloat(turn), y: center.y - CGFloat(turn)), radius: radius, startAngle: start, endAngle: start + .pi * 1.55, clockwise: true)
        }
        ring.path = path.cgPath
        emitter.emitterPosition = center
        emitter.emitterSize = CGSize(width: bounds.width, height: bounds.width)
    }

    func wiggle() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shake.values = [0, -0.18, 0.14, -0.08, 0.04, 0]
        shake.duration = 0.5
        layer.add(shake, forKey: "wiggle")
    }

    func burst() {
        wiggle()
        guard !UIAccessibility.isReduceMotionEnabled,
              let bolt = UIImage(systemName: "bolt.fill")?.withTintColor(PowerTheme.lighting.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal) else { return }
        let size = CGSize(width: 22, height: 26)
        let image = UIGraphicsImageRenderer(size: size).image { _ in bolt.draw(in: CGRect(origin: .zero, size: size)) }
        let cell = CAEmitterCell()
        cell.contents = image.cgImage
        cell.birthRate = 60
        cell.lifetime = 1.3
        cell.velocity = 220
        cell.velocityRange = 80
        cell.emissionRange = .pi * 2
        cell.spin = 3
        cell.spinRange = 6
        cell.scale = 0.9
        cell.scaleRange = 0.4
        cell.scaleSpeed = -0.5
        cell.alphaSpeed = -0.8
        cell.yAcceleration = 260
        emitter.emitterShape = .circle
        emitter.emitterCells = [cell]
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.emitter.birthRate = 0 }
    }

    private func updateRingColor() {
        ring.strokeColor = PowerTheme.accent.withAlphaComponent(0.45).resolvedColor(with: traitCollection).cgColor
    }
}

/// A slightly tilted note card with a strip of tape and a dashed edge.
private final class PaperNoteView: UIView {
    private let border = CAShapeLayer()

    init(text: String, signature: String) {
        super.init(frame: .zero)
        let paper = UIView()
        paper.backgroundColor = PowerTheme.surface
        paper.layer.cornerRadius = 6
        paper.layer.shadowColor = UIColor.black.cgColor
        paper.layer.shadowOpacity = 0.08
        paper.layer.shadowRadius = 10
        paper.layer.shadowOffset = CGSize(width: 0, height: 4)
        paper.transform = CGAffineTransform(rotationAngle: -0.012)
        paper.translatesAutoresizingMaskIntoConstraints = false
        addSubview(paper)
        border.fillColor = nil
        border.lineWidth = 1.2
        border.lineDashPattern = [6, 5]
        paper.layer.addSublayer(border)
        let body = UILabel.powerLabel(text, style: .body)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        body.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraph, .font: body.font!, .foregroundColor: UIColor.label])
        let sign = UILabel.powerLabel(signature, style: .callout, weight: .semibold, color: PowerTheme.accent)
        sign.font = UIFontMetrics(forTextStyle: .callout).scaledFont(for: UIFont.italicSystemFont(ofSize: 16))
        sign.textAlignment = .right
        let content = UIStackView(arrangedSubviews: [body, sign])
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        paper.addSubview(content)
        let tape = UIView()
        tape.backgroundColor = PowerTheme.lighting.withAlphaComponent(0.28)
        tape.transform = CGAffineTransform(rotationAngle: 0.06)
        tape.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tape)
        NSLayoutConstraint.activate([
            paper.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2), paper.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            paper.topAnchor.constraint(equalTo: topAnchor, constant: 10), paper.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            content.leadingAnchor.constraint(equalTo: paper.leadingAnchor, constant: 22), content.trailingAnchor.constraint(equalTo: paper.trailingAnchor, constant: -22),
            content.topAnchor.constraint(equalTo: paper.topAnchor, constant: 26), content.bottomAnchor.constraint(equalTo: paper.bottomAnchor, constant: -20),
            tape.centerXAnchor.constraint(equalTo: centerXAnchor), tape.topAnchor.constraint(equalTo: topAnchor),
            tape.widthAnchor.constraint(equalToConstant: 84), tape.heightAnchor.constraint(equalToConstant: 22)
        ])
        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PaperNoteView, _) in view.updateColors() }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let paper = subviews.first else { return }
        border.frame = paper.bounds
        border.path = UIBezierPath(roundedRect: paper.bounds.insetBy(dx: 7, dy: 7), cornerRadius: 3).cgPath
    }

    private func updateColors() {
        border.strokeColor = PowerTheme.accent.withAlphaComponent(0.22).resolvedColor(with: traitCollection).cgColor
    }
}

/// One stop on the release timeline; tap to reveal what changed.
private final class ReleaseRowView: PowerInteractiveControl {
    private let detailLabel: UILabel
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let onToggle: () -> Void
    private var expanded = false

    init(release: Changelog.Release, isLatest: Bool, isLast: Bool, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        detailLabel = UILabel.powerLabel(([release.summary] + release.sections.flatMap { $0.items }.map { "· " + $0 }).joined(separator: "\n"), style: .subheadline, color: .secondaryLabel)
        super.init(frame: .zero)
        let dot = UIView()
        dot.backgroundColor = isLatest ? PowerTheme.accent : PowerTheme.surface
        dot.layer.borderColor = PowerTheme.accent.resolvedColor(with: traitCollection).cgColor
        dot.layer.borderWidth = 2.5
        dot.layer.cornerRadius = 7
        let line = UIView()
        line.backgroundColor = PowerTheme.accent.withAlphaComponent(0.2)
        line.isHidden = isLast
        [dot, line].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        let version = UILabel.powerLabel(release.version, style: .headline, weight: .bold, color: PowerTheme.accent)
        version.setContentHuggingPriority(.required, for: .horizontal)
        let title = UILabel.powerLabel(release.title, style: .body, weight: .medium)
        chevron.tintColor = .tertiaryLabel
        chevron.preferredSymbolConfiguration = .init(pointSize: 12, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        var headerViews: [UIView] = [version, title]
        if isLatest {
            let new = StickerView("NEW", angle: -0.1)
            new.isUserInteractionEnabled = false
            new.fill = PowerTheme.lighting
            new.setContentHuggingPriority(.required, for: .horizontal)
            headerViews.append(new)
        }
        headerViews += [UIView(), chevron]
        let header = UIStackView(arrangedSubviews: headerViews)
        header.spacing = 10
        header.alignment = .center
        detailLabel.isHidden = true
        let content = UIStackView(arrangedSubviews: [header, detailLabel])
        content.axis = .vertical
        content.spacing = 8
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4), dot.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14), dot.heightAnchor.constraint(equalToConstant: 14),
            line.centerXAnchor.constraint(equalTo: dot.centerXAnchor), line.widthAnchor.constraint(equalToConstant: 2),
            line.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 4), line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 6),
            content.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 16), content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 12), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = "版本 \(release.version)，\(release.title)" + (isLatest ? "，最新" : "")
        accessibilityTraits = .button
        accessibilityHint = "轻点展开更新内容"
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func toggle() {
        expanded.toggle()
        accessibilityValue = expanded ? detailLabel.text : nil
        UISelectionFeedbackGenerator().selectionChanged()
        PowerMotion.animate {
            self.detailLabel.isHidden = !self.expanded
            self.detailLabel.alpha = self.expanded ? 1 : 0
            self.chevron.transform = self.expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        }
        onToggle()
    }
}
