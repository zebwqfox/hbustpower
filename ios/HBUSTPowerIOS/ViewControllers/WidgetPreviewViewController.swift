#if DEBUG
import SwiftUI
import UIKit
import WidgetKit

/// Renders the home-screen widgets at their real sizes inside the app, so the design can be checked without
/// adding them to the Home Screen first. Debug builds only.
final class WidgetPreviewViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "小组件预览"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = PowerTheme.background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        setContentScrollView(scrollView, for: .all)
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
        ])

        let snapshot = PowerWidgetStore.load() ?? PowerWidgetStore.placeholder
        let stored = PowerWidgetStore.load() == nil ? "（共享存储为空，使用演示数据）" : "（来自共享存储）"
        stack.addArrangedSubview(UILabel.powerLabel("当前主题：\(PowerTheme.style.name)\(stored)", style: .footnote, color: .secondaryLabel))
        for style in PowerThemeStyle.allCases {
            stack.addArrangedSubview(UILabel.powerLabel(style.name, style: .headline, weight: .bold, color: style.accent))
            add(SmallView(snapshot: snapshot, theme: style), size: CGSize(width: 170, height: 170), background: style.hero)
            add(MediumView(snapshot: snapshot, theme: style), size: CGSize(width: 364, height: 170), background: style.hero)
        }
        stack.addArrangedSubview(UILabel.powerLabel("没有数据时", style: .headline, weight: .bold))
        add(EmptyStateView(theme: PowerTheme.style, family: .systemSmall), size: CGSize(width: 170, height: 170), background: PowerTheme.style.hero)
    }

    private func add(_ content: some View, size: CGSize, background: UIColor) {
        let host = UIHostingController(rootView: content.padding(16))
        addChild(host)
        host.view.backgroundColor = background
        host.view.layer.cornerRadius = 22
        host.view.layer.cornerCurve = CALayerCornerCurve.continuous
        host.view.clipsToBounds = true
        host.view.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.widthAnchor.constraint(equalToConstant: size.width),
            host.view.heightAnchor.constraint(equalToConstant: size.height)
        ])
        host.didMove(toParent: self)
    }
}
#endif
