import UIKit

final class RootTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tabBar.isTranslucent = true
        delegate = self
        tabBarMinimizeBehavior = .never
        viewControllers = [
            navigation(OverviewViewController(model: model), title: "电量", image: "bolt.fill"),
            navigation(UsageViewController(model: model), title: "用量", image: "chart.bar.xaxis"),
            navigation(RecordsViewController(model: model), title: "充值记录", image: "clock.arrow.circlepath"),
            navigation(CampusCardViewController(model: model), title: "校园卡", image: "creditcard.fill"),
            navigation(SettingsViewController(model: model), title: "设置", image: "gearshape.fill")
        ]
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if selectedViewController !== viewController { UISelectionFeedbackGenerator().selectionChanged() }
        return true
    }

    private func navigation(_ root: UIViewController, title: String, image: String) -> UINavigationController {
        let controller = UINavigationController(rootViewController: root)
        controller.navigationBar.prefersLargeTitles = true
        controller.navigationBar.tintColor = PowerTheme.accent
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = PowerTheme.background
        appearance.shadowColor = .clear
        controller.navigationBar.standardAppearance = appearance
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        controller.navigationBar.scrollEdgeAppearance = edge
        controller.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: image), selectedImage: nil)
        return controller
    }
}
