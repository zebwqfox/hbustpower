import UIKit
import WebKit
import SafariServices

final class AuthenticationViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {

    private let model: AppModel
    private let webView: WKWebView
    private let nativeScroll = UIScrollView()
    private let content = UIStackView()
    private let accountField = UITextField()
    private let passwordField = UITextField()
    private let statusLabel = UILabel.powerLabel("", style: .footnote, color: .secondaryLabel)
    private let loginButton = PowerActionButton(type: .system)
    private let onCampusConnected: ((WKWebView) -> Void)?
    private var flowIcons: [UIImageView] = []
    private let loginAccent = UIColor(red: 0.25, green: 0.52, blue: 0.97, alpha: 1)
    private let consentButton = PowerActionButton(type: .system)
    private let alternativeButton = PowerActionButton(type: .system)
    private var agreed = false
    private var formReady = false
    private var submitting = false
    private var completed = false
    private var showingWeb = false
    private var monitor: Task<Void, Never>?
    private var navigationTimeout: Task<Void, Never>?
    private var cookieTransfer: Task<Void, Never>?

    init(model: AppModel, onCampusConnected: ((WKWebView) -> Void)? = nil) {
        self.onCampusConnected = onCampusConnected
        self.model = model
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        if onCampusConnected == nil {
            configuration.userContentController.addUserScript(WKUserScript(source: AuthenticationScripts.portal, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.customUserAgent = AuthenticationScripts.mobileUserAgent
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit {
        monitor?.cancel(); navigationTimeout?.cancel(); cookieTransfer?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "连接校园服务"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        preferredContentSize = CGSize(width: 460, height: 680)
        navigationController?.navigationBar.tintColor = loginAccent
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.shadowColor = .clear
        navigationItem.standardAppearance = bar
        navigationItem.scrollEdgeAppearance = bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.cancelLogin()
        })
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.isOpaque = false
        webView.backgroundColor = PowerTheme.background
        view.addSubview(webView)
        nativeScroll.translatesAutoresizingMaskIntoConstraints = false
        nativeScroll.keyboardDismissMode = .interactive
        view.addSubview(nativeScroll)
        setContentScrollView(nativeScroll, for: .all)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor), webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            nativeScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), nativeScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nativeScroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        configureForm()
#if DEBUG
        if CommandLine.arguments.contains("--native-login-preview") {
            formReady = true
            statusLabel.text = ""
            updateButton()
            return
        }
#endif
        loadLogin()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            monitor?.cancel(); navigationTimeout?.cancel(); cookieTransfer?.cancel()
            if onCampusConnected == nil || !completed { webView.stopLoading() }
            passwordField.text = nil
        }
    }

    private func configureForm() {
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        nativeScroll.addSubview(content)
        let width = content.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        width.priority = .init(999)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 380), width,
            nativeScroll.contentLayoutGuide.widthAnchor.constraint(equalTo: nativeScroll.frameLayoutGuide.widthAnchor),
            content.topAnchor.constraint(equalTo: nativeScroll.contentLayoutGuide.topAnchor, constant: 32),
            content.bottomAnchor.constraint(equalTo: nativeScroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
        let logo = UIImageView(image: UIImage(named: "XuexitongLogo"))
        logo.contentMode = .scaleAspectFit
        logo.widthAnchor.constraint(equalToConstant: 52).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 52).isActive = true
        logo.isAccessibilityElement = true
        logo.accessibilityLabel = "学习通 Logo"
        let brand = UIStackView(arrangedSubviews: [logo, UILabel.powerLabel("学习通", style: .title3, weight: .medium)])
        brand.alignment = .center
        brand.spacing = 12
        content.addArrangedSubview(brand)
        content.setCustomSpacing(30, after: brand)
        let stages = UIStackView(); stages.axis = .horizontal; stages.distribution = .fillEqually; stages.spacing = 8
        for (symbol, label) in [("person.crop.circle", "身份验证"), ("creditcard", "校园卡授权"), ("bolt", onCampusConnected == nil ? "查看电量" : "查看余额")] {
            let icon = UIImageView(image: UIImage(systemName: symbol)); icon.contentMode = .scaleAspectFit
            icon.heightAnchor.constraint(equalToConstant: 26).isActive = true
            flowIcons.append(icon)
            let text = UILabel.powerLabel(label, style: .caption1); text.textAlignment = .center
            let stage = UIStackView(arrangedSubviews: [icon, text]); stage.axis = .vertical; stage.spacing = 8
            stages.addArrangedSubview(stage)
        }
        content.addArrangedSubview(stages)
        setFlowStage(0)
        let detail = UILabel.powerLabel(onCampusConnected == nil
            ? "使用学习通完成验证。验证通过后，即可查看已绑定宿舍的电量。"
            : "使用学习通完成验证。验证通过后，即可查看校园卡余额。", style: .footnote, color: .secondaryLabel)
        content.addArrangedSubview(detail)
        content.setCustomSpacing(24, after: detail)
        configureField(accountField, placeholder: "手机号 / 超星号", secure: false)
        configureField(passwordField, placeholder: "学习通密码", secure: true)
        let inputGlass = UIGlassEffect()
        inputGlass.isInteractive = true
        let inputMaterial = UIVisualEffectView(effect: inputGlass)
        inputMaterial.cornerConfiguration = .uniformCorners(radius: .fixed(28))
        inputMaterial.accessibilityIdentifier = "auth.glassFields"
        let separator = UIView()
        separator.backgroundColor = UIColor.label.withAlphaComponent(0.09)
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let fields = UIStackView(arrangedSubviews: [accountField, separator, passwordField])
        fields.axis = .vertical
        fields.translatesAutoresizingMaskIntoConstraints = false
        inputMaterial.contentView.addSubview(fields)
        NSLayoutConstraint.activate([
            fields.leadingAnchor.constraint(equalTo: inputMaterial.contentView.leadingAnchor, constant: 6),
            fields.trailingAnchor.constraint(equalTo: inputMaterial.contentView.trailingAnchor, constant: -6),
            fields.topAnchor.constraint(equalTo: inputMaterial.contentView.topAnchor, constant: 6),
            fields.bottomAnchor.constraint(equalTo: inputMaterial.contentView.bottomAnchor, constant: -6)
        ])
        content.addArrangedSubview(inputMaterial)
        content.setCustomSpacing(26, after: inputMaterial)

        loginButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(submitLogin), for: .touchUpInside)
        content.addArrangedSubview(loginButton)

        var alternative = UIButton.Configuration.glass()
        alternative.title = "打开学习通官方页面"
        alternative.image = UIImage(systemName: "person.crop.circle")
        alternative.imagePadding = 8
        alternative.baseForegroundColor = loginAccent
        alternative.contentInsets = .init(top: 14, leading: 18, bottom: 14, trailing: 18)
        alternative.cornerStyle = .capsule
        alternativeButton.configuration = alternative
        alternativeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        alternativeButton.addAction(UIAction { [weak self] _ in self?.showOfficialPage() }, for: .touchUpInside)
        content.addArrangedSubview(alternativeButton)
        content.setCustomSpacing(26, after: alternativeButton)

        configureTextButton(consentButton, title: "我已阅读并同意以下条款")
        consentButton.configuration?.image = UIImage(systemName: "square")
        consentButton.configuration?.preferredSymbolConfigurationForImage = .init(pointSize: 15, weight: .regular)
        consentButton.configuration?.imagePadding = 7
        consentButton.accessibilityValue = "未同意"
        consentButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.agreed.toggle()
            self.consentButton.configuration?.image = UIImage(systemName: self.agreed ? "checkmark.square.fill" : "square")
            self.consentButton.accessibilityValue = self.agreed ? "已同意" : "未同意"
            self.updateButton()
        }, for: .touchUpInside)
        content.addArrangedSubview(consentButton)
        content.setCustomSpacing(0, after: consentButton)
        let policies = UIStackView()
        policies.distribution = .fillEqually
        policies.spacing = 12
        for (label, path) in [("《隐私政策》", "privacyPolicy"), ("《用户协议》", "userAgreement")] {
            let button = PowerActionButton(type: .system)
            configureTextButton(button, title: label)
            button.addAction(UIAction { [weak self] _ in
                guard let url = URL(string: "https://homewh.chaoxing.com/agree/\(path)?appId=900001") else { return }
                self?.present(SFSafariViewController(url: url), animated: true)
            }, for: .touchUpInside)
            policies.addArrangedSubview(button)
        }
        content.addArrangedSubview(policies)
        statusLabel.textAlignment = .center
        statusLabel.accessibilityIdentifier = "auth.status"
        content.addArrangedSubview(statusLabel)
        updateButton()
    }

    private func setFlowStage(_ index: Int) {
        for (position, icon) in flowIcons.enumerated() {
            icon.image = UIImage(systemName: position < index ? "checkmark.circle.fill" : ["person.crop.circle", "creditcard", onCampusConnected == nil ? "bolt" : "creditcard.fill"][position])
            icon.tintColor = position <= index ? loginAccent : .tertiaryLabel
        }
    }

    private func configureTextButton(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = loginAccent
        configuration.contentInsets = .init(top: 8, leading: 4, bottom: 8, trailing: 4)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var value = incoming
            value.font = .preferredFont(forTextStyle: .footnote)
            return value
        }
        button.configuration = configuration
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func configureField(_ field: UITextField, placeholder: String, secure: Bool) {
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
        field.accessibilityIdentifier = secure ? "auth.password" : "auth.account"
        field.isSecureTextEntry = secure
        field.textContentType = secure ? .password : .username
        field.keyboardType = secure ? .default : .asciiCapable
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.tintColor = loginAccent
        field.backgroundColor = .clear
        let iconHost = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 48))
        let icon = UIImageView(image: UIImage(systemName: secure ? "lock.fill" : "iphone"))
        icon.tintColor = loginAccent.withAlphaComponent(0.8)
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 17, y: 15, width: 15, height: 18)
        iconHost.addSubview(icon)
        field.leftView = iconHost
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.rightViewMode = .always
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        field.returnKeyType = secure ? .go : .next
        field.delegate = self
        field.addTarget(self, action: #selector(fieldsChanged), for: .editingChanged)
    }

    @objc private func fieldsChanged() { updateButton() }
    private func updateButton() {
        loginButton.isEnabled = formReady && agreed && !submitting && !(accountField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !(passwordField.text ?? "").isEmpty
        let prominent = loginButton.isEnabled || submitting
        var appearance = prominent ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        appearance.title = "登录并连接"
        appearance.baseBackgroundColor = loginAccent
        appearance.baseForegroundColor = prominent ? UIColor.white : loginAccent
        appearance.cornerStyle = .capsule
        appearance.contentInsets = .init(top: 14, leading: 24, bottom: 14, trailing: 24)
        let foreground: UIColor = prominent ? .white : loginAccent
        appearance.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var value = incoming
            value.font = UIFont.preferredFont(forTextStyle: .headline)
            value.foregroundColor = foreground
            return value
        }
        appearance.showsActivityIndicator = submitting
        loginButton.configuration = appearance

    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === accountField { passwordField.becomeFirstResponder() }
        else if loginButton.isEnabled { submitLogin() }
        return true
    }

    private func loadLogin() {
        formReady = false
        submitting = false
        statusLabel.text = ""
        alternativeButton.configuration?.title = "打开学习通官方页面"
        updateButton()
        webView.load(URLRequest(url: ElectricityService.chaoxingAuthURL))
        startTimeout()
    }

    @objc private func submitLogin() {
        guard loginButton.isEnabled, AuthenticationScripts.isLoginForm(webView.url) else { return }
        submitting = true
        statusLabel.text = ""
        view.endEditing(true)
        updateButton()
        let arguments: [String: Any] = ["account": (accountField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "password": passwordField.text ?? "", "agreed": agreed]
        webView.callAsyncJavaScript(AuthenticationScripts.submit, arguments: arguments, in: nil, in: .page) { [weak self] result in
            guard let self, !self.completed else { return }
            self.passwordField.text = nil
            switch result {
            case .success(let submitted) where submitted as? Bool == true:
                self.monitorLoginResult()
            default:
                self.submitting = false
                self.statusLabel.text = "当前登录方式需要在官方页面继续。"
                self.showOfficialPage()
            }
            self.updateButton()
        }
        startTimeout()
    }

    private func monitorLoginResult() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled, !self.completed, !self.showingWeb else { return }
                guard AuthenticationScripts.isLoginForm(self.webView.url) else { continue }
                if let message = try? await self.webView.evaluateJavaScript(AuthenticationScripts.errorText) as? String, !message.isEmpty {
                    self.statusLabel.text = message
                    self.submitting = false
                    self.updateButton()
                    self.navigationTimeout?.cancel()
                    return
                }
            }
        }
    }

    private func startTimeout() {
        navigationTimeout?.cancel()
        navigationTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, !Task.isCancelled, !self.completed else { return }
            self.submitting = false
            self.statusLabel.text = "连接耗时较长，请检查网络后重试。"
            self.updateButton()
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "重试", primaryAction: UIAction { [weak self] _ in self?.retryCurrentProvider() })
        }
    }

    private func retryCurrentProvider() {
        loadLogin()
    }

    private func returnToNativeLogin() {
        showingWeb = false
        nativeScroll.isHidden = false
        webView.isHidden = true
        setContentScrollView(nativeScroll, for: .all)
        title = "连接校园服务"
        submitting = false
        navigationItem.rightBarButtonItem = nil
        loadLogin()
    }

    private func showOfficialPage() {
        showingWeb = true
        monitor?.cancel()
        view.endEditing(true)
        nativeScroll.isHidden = true
        webView.isHidden = false
        setContentScrollView(webView.scrollView, for: .all)
        title = "超星官方验证"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "返回", primaryAction: UIAction { [weak self] _ in
            self?.returnToNativeLogin()
        })
    }

    private func cancelLogin() {
        completed = true
        monitor?.cancel(); navigationTimeout?.cancel(); cookieTransfer?.cancel()
        passwordField.text = nil
        webView.stopLoading()
        dismiss(animated: true)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
#if DEBUG
        // Host and path only: never log queries, which carry authorization codes and tokens.
        let names = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name).joined(separator: ",") ?? ""
        print("AUTH_NAV main=\(navigationAction.targetFrame?.isMainFrame ?? true) \(url.scheme ?? "")://\(url.host ?? "")\(url.path) params=[\(names)] valid=\(ElectricityService.isValidElectricityRedirect(url))")
#endif
        if onCampusConnected == nil, (navigationAction.targetFrame?.isMainFrame ?? true), ElectricityService.isValidElectricityRedirect(url) {
            decisionHandler(.cancel)
            guard !completed else { return }
            completed = true
            monitor?.cancel(); navigationTimeout?.cancel()
            passwordField.text = nil
            setFlowStage(2)
            PowerDiagnostics.shared.record("登录授权已取得，正在读取电量")
            cookieTransfer = Task { [weak self] in
                guard let self else { return }
                let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
                guard !Task.isCancelled else { return }
                for cookie in cookies where cookie.domain == "hbust.edu.cn" || cookie.domain.hasSuffix(".hbust.edu.cn") {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                self.model.completeAuthentication(with: url)
                self.dismiss(animated: true)
            }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
#if DEBUG
        print("AUTH_FINISH \(webView.url?.host ?? "")\(webView.url?.path ?? "") completed=\(completed)")
#endif
        guard !completed else { return }
        if AuthenticationScripts.isLoginForm(webView.url) {
            webView.evaluateJavaScript(AuthenticationScripts.formReady) { [weak self] result, _ in
                guard let self, AuthenticationScripts.isLoginForm(self.webView.url) else { return }
                self.formReady = result as? Bool == true
#if DEBUG
                if CommandLine.arguments.contains("--live-login-check") { print("AUTH_LIVE_FORM ready=\(self.formReady)") }
#endif
                self.statusLabel.text = self.formReady ? "" : "可通过其他登录方式继续官方验证。"
                self.navigationTimeout?.cancel()
                self.updateButton()
            }
        } else if AuthenticationScripts.isCampusPortal(webView.url) {
            setFlowStage(1)
            if let onCampusConnected {
                completed = true
                monitor?.cancel(); navigationTimeout?.cancel()
                passwordField.text = nil
                let portal = webView
                dismiss(animated: true) { onCampusConnected(portal) }
                return
            }
            showingWeb = false
            nativeScroll.isHidden = false
            webView.isHidden = true
            setContentScrollView(nativeScroll, for: .all)
            title = "连接校园服务"
            alternativeButton.configuration?.title = "打开校园卡页面"
            statusLabel.text = ""
            submitting = true
            formReady = false
            updateButton()
            PowerDiagnostics.shared.record("已到达一卡通，等待宿舍电费入口")
            webView.evaluateJavaScript(AuthenticationScripts.portal)
            startTimeout()
        } else if ["passport2.chaoxing.com", "auth.chaoxing.com"].contains(webView.url?.host?.lowercased() ?? "") {
            // Captcha, weak-password changes and second-factor checks remain fully user driven.
            showOfficialPage()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) { handleFailure(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) { handleFailure(error) }
    private func handleFailure(_ error: Error) {
#if DEBUG
        print("AUTH_FAIL \((error as NSError).domain) \((error as NSError).code)")
#endif
        guard !completed, (error as NSError).code != NSURLErrorCancelled else { return }
        navigationTimeout?.cancel()
        submitting = false
        statusLabel.text = "连接未成功，请检查网络后重试。"
        PowerDiagnostics.shared.record("登录连接失败：" + PowerDiagnostics.errorSummary(error))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "重试", primaryAction: UIAction { [weak self] _ in self?.retryCurrentProvider() })
        updateButton()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
}
