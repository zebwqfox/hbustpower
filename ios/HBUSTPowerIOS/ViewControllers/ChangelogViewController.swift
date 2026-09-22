import UIKit

/// Every release, newest first, grouped into 新增 / 改进 / 修复.
final class ChangelogViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private lazy var maxWidth = stack.widthAnchor.constraint(lessThanOrEqualToConstant: PowerLayout.readableWidth)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "更新日志"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = PowerTheme.background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        setContentScrollView(scrollView, for: .all)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            maxWidth
        ])
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = UILayoutPriority(999)
        width.isActive = true

        stack.addArrangedSubview(DoodleHeadingView("每一版都改了什么", detail: "从新到旧，共 \(Changelog.releases.count) 个版本", seed: 17))
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        for release in Changelog.releases {
            stack.addArrangedSubview(ReleaseCardView(release: release, isInstalled: release.version == current))
        }
    }
}

private final class ReleaseCardView: UIView {
    init(release: Changelog.Release, isInstalled: Bool) {
        super.init(frame: .zero)
        backgroundColor = PowerTheme.surface
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        let version = UILabel.powerLabel(release.version, style: .title2, weight: .bold, color: PowerTheme.accent)
        version.setContentHuggingPriority(.required, for: .horizontal)
        var headerViews: [UIView] = [version]
        if isInstalled {
            let sticker = StickerView("当前版本", angle: -0.08)
            sticker.fill = PowerTheme.lighting
            sticker.setContentHuggingPriority(.required, for: .horizontal)
            headerViews.append(sticker)
        }
        headerViews.append(UIView())
        let header = UIStackView(arrangedSubviews: headerViews)
        header.spacing = 10
        header.alignment = .center
        let content = UIStackView(arrangedSubviews: [
            header,
            UILabel.powerLabel(release.title, style: .headline, weight: .semibold),
            UILabel.powerLabel(release.summary, style: .subheadline, color: .secondaryLabel)
        ])
        content.axis = .vertical
        content.spacing = 4
        content.setCustomSpacing(8, after: header)
        for section in release.sections {
            let tag = UILabel.powerLabel(section.title, style: .caption1, weight: .bold, color: tint(for: section.title))
            content.addArrangedSubview(tag)
            content.setCustomSpacing(14, after: content.arrangedSubviews[content.arrangedSubviews.count - 2])
            content.setCustomSpacing(6, after: tag)
            for item in section.items {
                let row = UIStackView(arrangedSubviews: [UILabel.powerLabel("•", style: .body, color: tint(for: section.title)), UILabel.powerLabel(item, style: .body)])
                row.spacing = 8
                row.alignment = .firstBaseline
                row.arrangedSubviews[0].setContentHuggingPriority(.required, for: .horizontal)
                content.addArrangedSubview(row)
            }
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 18), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func tint(for section: String) -> UIColor {
        switch section {
        case "新增": PowerTheme.accent
        case "修复": PowerTheme.lighting
        default: .secondaryLabel
        }
    }
}
