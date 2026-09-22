import UIKit

final class FirstRunViewController: UIViewController {
    private let flow: FirstRunFlow
    private let completion: () -> Void
    private let stack = UIStackView()
    private let symbol = UIImageView()
    private let heading = UILabel.powerLabel(nil, style: .largeTitle, weight: .semibold)
    private let detail = UILabel.powerLabel(nil, style: .body, color: .secondaryLabel)
    private let primary = PowerTheme.button("开启通知", primary: true)
    private let secondary = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let pages = UIPageControl()
    private var observer: NSObjectProtocol?
    private var task: Task<Void, Never>?
    private var deliveredCompletion = false
    init(flow: FirstRunFlow, completion: @escaping () -> Void) { self.flow = flow; self.completion = completion; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit { task?.cancel(); if let observer { NotificationCenter.default.removeObserver(observer) } }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48); width.priority = .init(999)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor), width,
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 64),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
        symbol.tintColor = PowerTheme.accent; symbol.contentMode = .scaleAspectFit
        symbol.preferredSymbolConfiguration = .init(pointSize: 72, weight: .light)
        symbol.heightAnchor.constraint(equalToConstant: 112).isActive = true
        heading.textAlignment = .center; detail.textAlignment = .center
        secondary.configuration = .plain(); secondary.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        backButton.configuration = .plain(); backButton.setTitle("返回", for: .normal)
        backButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        pages.numberOfPages = 2; pages.isUserInteractionEnabled = false
        pages.currentPageIndicatorTintColor = PowerTheme.accent; pages.pageIndicatorTintColor = .systemGray4
        [symbol, heading, detail, primary, secondary, backButton, pages].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(44, after: detail)
        primary.addAction(UIAction { [weak self] _ in self?.advance() }, for: .touchUpInside)
        secondary.addAction(UIAction { [weak self] _ in self?.flow.continueWithoutPermission(); self?.render(animated: true) }, for: .touchUpInside)
        backButton.addAction(UIAction { [weak self] _ in self?.flow.back(); self?.render(animated: true) }, for: .touchUpInside)
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.flow.refreshAuthorization()
                self.render(animated: false)
            }
        }
        render(animated: false)
    }
    private func advance() {
        guard !flow.busy else { return }
        switch flow.step {
        case .introduction:
            flow.finish()
            guard !deliveredCompletion else { return }
            deliveredCompletion = true; completion()
        case .permissionDenied:
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
        case .permission:
            primary.isEnabled = false; secondary.isEnabled = false; backButton.isEnabled = false
            primary.configuration?.showsActivityIndicator = true
            task = Task { [weak self] in
                guard let self else { return }
                await flow.requestPermission()
                guard !Task.isCancelled else { return }
                render(animated: true)
            }
        case .finished: break
        }
    }
    private func render(animated: Bool) {
        primary.isEnabled = !flow.busy; secondary.isEnabled = !flow.busy; backButton.isEnabled = !flow.busy
        primary.configuration?.showsActivityIndicator = flow.busy
        let intro = flow.step == .introduction
        pages.currentPage = intro ? 1 : 0
        backButton.isHidden = !intro; secondary.isHidden = intro
        symbol.image = UIImage(systemName: intro ? "bolt" : "bell.badge")
        switch flow.step {
        case .permission:
            heading.text = "低电量时提醒"
            detail.text = flow.error ?? "开启通知，在电量更新后接收低电量提醒。"
            primary.configuration?.title = "开启通知"
            secondary.setTitle("暂不开启", for: .normal)
        case .permissionDenied:
            heading.text = "通知未开启"
            detail.text = "可在系统设置中开启，也可以继续使用。"
            primary.configuration?.title = "打开设置"
            secondary.setTitle("继续", for: .normal)
        case .introduction:
            heading.text = "电量，心中有数"
            detail.text = "首页看剩余电量与预计时长，下拉刷新。"
            primary.configuration?.title = "开始使用"
        case .finished: return
        }
        if animated {
            if UIAccessibility.isReduceMotionEnabled {
                stack.alpha = 0
                UIView.animate(withDuration: 0.18) { self.stack.alpha = 1 }
            } else { PowerMotion.reveal([symbol, heading, detail, primary]) }
            UIAccessibility.post(notification: .screenChanged, argument: heading)
        }
    }
}
