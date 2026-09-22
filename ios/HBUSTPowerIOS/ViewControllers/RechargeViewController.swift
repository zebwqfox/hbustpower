import UIKit
import WebKit

final class RechargeViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let model: AppModel
    private let webView: WKWebView
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let onFinish: () -> Void
    private var progressObservation: NSKeyValueObservation?
    private var modelObserver: NSObjectProtocol?
    private var hasFinished = false

    init(model: AppModel, onFinish: @escaping () -> Void) {
        self.model = model
        self.onFinish = onFinish
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        modelObserver = NotificationCenter.default.addObserver(
            forName: .powerModelDidChange, object: model, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.model.isFeatureEnabled(CloudConfig.flagRecharge) else { return }
                self.webView.stopLoading()
                self.finishAndDismiss()
            }
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit { if let modelObserver { NotificationCenter.default.removeObserver(modelObserver) } }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard model.isFeatureEnabled(CloudConfig.flagRecharge) else {
            dismiss(animated: false)
            return
        }
        title = "官方电费充值"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.finishAndDismiss() }
        )

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        toolbarItems = [
            UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { [weak self] _ in self?.webView.goBack() }),
            .flexibleSpace(),
            UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), primaryAction: UIAction { [weak self] _ in self?.webView.goForward() }),
            .flexibleSpace(),
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in self?.webView.reload() })
        ]
        navigationController?.isToolbarHidden = false

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.progress = Float(webView.estimatedProgress)
                self?.progressView.isHidden = webView.estimatedProgress >= 1
            }
        }
        importSessionAndLoad()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            completeOnce()
        }
    }

    private func importSessionAndLoad() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            self?.webView.load(URLRequest(url: ElectricityService.rechargeURL))
        }
    }

    private func exportSession(completion: @escaping () -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func finishAndDismiss() {
        exportSession { [weak self] in
            guard let self else { return }
            self.completeOnce()
            self.dismiss(animated: true)
        }
    }

    private func completeOnce() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        title = webView.title?.isEmpty == false ? webView.title : "官方电费充值"
        toolbarItems?[0].isEnabled = webView.canGoBack
        toolbarItems?[2].isEnabled = webView.canGoForward
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = url.scheme?.lowercased()
        if scheme != "http", scheme != "https", scheme != "about" {
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确认", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
