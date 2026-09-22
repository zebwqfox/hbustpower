import UIKit
import WebKit

final class CampusCardViewController: UIViewController, WKNavigationDelegate {
    private let model: AppModel
    private var webView = WKWebView(frame: .zero, configuration: {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        return configuration
    }())
    private let amount = UILabel.powerLabel("—", style: .largeTitle, weight: .semibold)
    private let note = UILabel.powerLabel(nil, style: .footnote, color: .secondaryLabel)
    private let login = PowerTheme.button("连接校园卡", image: "person.crop.circle")
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var task: Task<Void, Never>?
    private var generation = 0
    private var watchdog: Task<Void, Never>?
    private var portalEstablished = false
    private var hasBalance = false
    private var observer: NSObjectProtocol?
    private var foreground: NSObjectProtocol?

    init(model: AppModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit {
        task?.cancel(); watchdog?.cancel()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let foreground { NotificationCenter.default.removeObserver(foreground) }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "校园卡"
        view.backgroundColor = PowerTheme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in self?.refresh() })
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        setContentScrollView(scroll, for: .all)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48); width.priority = .init(999)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor), width, stack.widthAnchor.constraint(lessThanOrEqualToConstant: 620),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
        let card = PowerCardView(spacing: 20, glass: true, tint: PowerTheme.hero, cornerRadius: 30, contentInsets: .init(top: 32, leading: 24, bottom: 32, trailing: 24))
        let icon = UIImageView(image: UIImage(systemName: "creditcard.fill")); icon.tintColor = PowerTheme.accent; icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let label = UILabel.powerLabel("校园卡余额", style: .headline, color: PowerTheme.accent); label.textAlignment = .center
        amount.font = PowerTheme.font(62, weight: .semibold, style: .largeTitle); amount.textAlignment = .center; amount.adjustsFontSizeToFitWidth = true; amount.minimumScaleFactor = 0.5
        amount.accessibilityIdentifier = "campus.balance"
        note.textAlignment = .center
        [icon, label, amount, spinner, note].forEach(card.stack.addArrangedSubview)
        stack.addArrangedSubview(card)
        login.addAction(UIAction { [weak self] _ in self?.connect() }, for: .touchUpInside)
        stack.addArrangedSubview(login)
        let recharge = PowerTheme.button("前往智慧湖科充值", image: "arrow.up.right", primary: true)
        recharge.addAction(UIAction { [weak self] _ in
            UIApplication.shared.open(CampusCardScripts.portalURL) { success in
                if !success { DispatchQueue.main.async { self?.note.text = "无法打开智慧湖科，请稍后重试。" } }
            }
        }, for: .touchUpInside)
        stack.addArrangedSubview(recharge)
        webView.navigationDelegate = self
        webView.customUserAgent = AuthenticationScripts.mobileUserAgent
        webView.isHidden = true
        view.addSubview(webView)
        observer = NotificationCenter.default.addObserver(forName: .powerModelDidChange, object: model, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.status == .authenticationRequired, !self.model.hasSavedLogin else { return }
                self.generation += 1; self.task?.cancel(); self.watchdog?.cancel(); self.webView.stopLoading(); self.portalEstablished = false
                self.hasBalance = false; self.amount.text = "—"; self.note.text = nil; self.login.isHidden = false; self.spinner.stopAnimating()
            }
        }
        foreground = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.viewIfLoaded?.window != nil, self.presentedViewController == nil else { return }
                self.refresh()
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        generation += 1; task?.cancel(); watchdog?.cancel(); webView.stopLoading(); spinner.stopAnimating()
    }
    private func connect() {
        let auth = AuthenticationViewController(model: model, onCampusConnected: { [weak self] portal in
            guard let self else { return }
            self.adoptPortal(portal)
        })
        present(UINavigationController(rootViewController: auth), animated: true)
    }
    // Preserve the original browsing context, including origin-scoped sessionStorage.
    func adoptPortal(_ portal: WKWebView) {
        // sessionStorage belongs to this exact WebView, not WKWebsiteDataStore.
        generation += 1; task?.cancel(); watchdog?.cancel()
        webView.stopLoading(); webView.removeFromSuperview()
        portal.removeFromSuperview()
        webView = portal
        portal.navigationDelegate = self
        portal.uiDelegate = nil
        portal.isHidden = true
        view.addSubview(portal)
        portalEstablished = true
        PowerDiagnostics.shared.record("校园卡：接管已授权页面")
        refresh(reusePage: true)
    }
#if DEBUG
    var portalForVerification: WKWebView { webView }
#endif
    private func refresh(reusePage: Bool = false) {
        generation += 1; task?.cancel(); watchdog?.cancel()
#if DEBUG
        if CommandLine.arguments.contains("--ui-preview") {
            display(42.50, count: 1); return
        }
#endif
        note.text = hasBalance ? "更新中，显示上次余额" : nil
        login.isHidden = true; spinner.startAnimating()
        if !reusePage {
            // A new page has no portal sessionStorage: enter through the official SSO chain.
            webView.load(URLRequest(url: portalEstablished ? CampusCardScripts.portalURL : ElectricityService.authURL))
        }
        PowerDiagnostics.shared.record("校园卡：" + (reusePage ? "继续授权页面" : (portalEstablished ? "刷新已有会话" : "恢复官方授权")))
        let expected = generation
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard let self, !Task.isCancelled, self.generation == expected else { return }
            self.failed(reason: "查询超时")
        }
        task = Task { [weak self] in
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled, self.generation == expected else { return }
                if AuthenticationScripts.isLoginForm(self.webView.url) {
                    self.portalEstablished = false
                    self.failed(reason: "需要学习通授权")
                    return
                }
                guard AuthenticationScripts.isCampusPortal(self.webView.url),
                      (try? await self.webView.evaluateJavaScript(CampusCardScripts.ready)) as? Bool == true else { continue }
                do {
                    let result: Any = try await withCheckedThrowingContinuation { continuation in
                        self.webView.callAsyncJavaScript(CampusCardScripts.read, arguments: [:], in: nil, in: .page) { result in
                            continuation.resume(with: result)
                        }
                    }
                    guard !Task.isCancelled, self.generation == expected else { return }
                    guard let values = result as? [String: Any], let value = values["amount"] as? Double, value.isFinite,
                          let count = values["count"] as? Int, count > 0 else { throw ElectricityError.parseFailed }
                    self.portalEstablished = true
                    self.display(value, count: count)
                } catch {
                    guard !Task.isCancelled, self.generation == expected else { return }
                    self.failed(reason: "余额接口未返回有效数据")
                }
                return
            }
            guard let self, !Task.isCancelled, self.generation == expected else { return }
            self.failed(reason: "校园卡页面未就绪")
        }
    }
    private func display(_ value: Double, count: Int) {
        watchdog?.cancel()
        PowerDiagnostics.shared.record("校园卡：余额读取完成")
        hasBalance = true; amount.text = String(format: "¥ %.2f", value)
        amount.accessibilityLabel = String(format: "校园卡余额 %.2f 元", value)
        note.text = count > 1 ? "\(count) 张校园卡合计" : nil
        spinner.stopAnimating(); login.isHidden = true
    }
    private func failed(reason: String = "校园卡网络连接失败") {
        generation += 1; task?.cancel(); watchdog?.cancel()
        PowerDiagnostics.shared.record("校园卡：" + reason)
        spinner.stopAnimating(); login.isHidden = false
        note.text = hasBalance ? "余额未更新，可重新连接校园卡。" : "暂时无法读取余额，请连接校园卡后重试。"
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        generation += 1; task?.cancel(); failed()
    }
}
