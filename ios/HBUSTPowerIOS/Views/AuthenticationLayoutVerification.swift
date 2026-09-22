#if DEBUG
import UIKit
import WebKit

@MainActor
enum AuthenticationLayoutVerification {
    static func run(root: RootTabBarController) {
        if CommandLine.arguments.contains("--verify-layout") {
            Task { await verifyLayout(root) }
        }
        if CommandLine.arguments.contains("--verify-authentication") {
            Task { await verifyAuthentication() }
        }
    }

    private static func verifyLayout(_ root: RootTabBarController) async {
        for index in 0..<(root.viewControllers?.count ?? 0) {
            root.selectedIndex = index
            let nav = root.viewControllers![index] as! UINavigationController
            let page = nav.topViewController!
            page.loadViewIfNeeded()
            root.view.layoutIfNeeded()
            guard let scroll = page.contentScrollView(for: .top) else { preconditionFailure("No registered scroll view") }
            precondition(page.view.subviews.first === scroll, "Scroll view must be first, not backdrop")
            let inset = scroll.contentInset
            scroll.contentInset.bottom += 1400
            scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
            try? await Task.sleep(for: .milliseconds(400))
            let expanded = nav.navigationBar.frame.height
            scroll.setContentOffset(CGPoint(x: 0, y: 240), animated: false)
            try? await Task.sleep(for: .milliseconds(500))
            let collapsed = nav.navigationBar.frame.height
            precondition(collapsed < expanded - 10, "Title failed to collapse: \(page.title ?? "") \(expanded) → \(collapsed)")
            print("LAYOUT_CHECK PASS: \(page.title ?? "") \(expanded) → \(collapsed)")
            scroll.contentInset = inset
            scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
        }
        root.selectedIndex = 0
        print("LAYOUT_CHECK COMPLETE: all scrolling titles collapse")
    }

    private final class Fixture: NSObject, WKNavigationDelegate {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 420, height: 720))
        private var loaded: CheckedContinuation<Void, Error>?
        override init() { super.init(); web.navigationDelegate = self }
        func load(_ html: String, at url: URL) async throws {
            try await withCheckedThrowingContinuation { continuation in
                loaded = continuation
                web.loadHTMLString(html, baseURL: url)
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) { loaded?.resume(); loaded = nil }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) { loaded?.resume(throwing: error); loaded = nil }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) { loaded?.resume(throwing: error); loaded = nil }
    }

    private static func verifyAuthentication() async {
        do {
            precondition(AuthenticationScripts.isLoginForm(URL(string: "https://passport2.chaoxing.com/mlogin")))
            for raw in ["http://passport2.chaoxing.com/mlogin", "https://passport2.chaoxing.com.evil.invalid/mlogin", "https://passport2.chaoxing.com/v11/updateweakpwd"] {
                precondition(!AuthenticationScripts.isLoginForm(URL(string: raw)))
            }
            precondition(AuthenticationScripts.isSchoolSSOEntry(ElectricityService.schoolSSOAuthURL))
            precondition(AuthenticationScripts.isSchoolSSO(URL(string: "http://sso.hbust.edu.cn:28000/login/oauth/authorize")))
            for raw in [
                "https://sso.hbust.edu.cn:28000/login/oauth/authorize",
                "http://sso.hbust.edu.cn/login/oauth/authorize",
                "http://sso.hbust.edu.cn.evil.invalid:28000/login/oauth/authorize",
                "http://sso.hbust.edu.cn:28000/other"
            ] {
                precondition(!AuthenticationScripts.isSchoolSSO(URL(string: raw)))
            }
            precondition(!ElectricityService.isValidElectricityRedirect(URL(string: "https://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&appId=180&synjones-auth=test")!))
            print("AUTH_CHECK PASS: exact Chaoxing and school SSO origins; duplicate redirect rejection")
            let fixture = Fixture()
            try await fixture.load(#"""
            <html><body><input id="phone"><input id="pwd" type="password">
            <div class="prompt-info"><span class="checkBox" onclick="this.classList.toggle('checkedBox')">consent</span></div>
            <button onclick="hasAgreePolicy(loginByPhoneAndPwd) && loginByPhoneAndPwd()">login</button>
            <script>var submitted = 0; function hasAgreePolicy() { return document.querySelector('.checkBox').classList.contains('checkedBox'); }
            function loginByPhoneAndPwd() { submitted++; }</script></body></html>
            """#, at: URL(string: "https://passport2.chaoxing.com/mlogin")!)
            let ready = try await fixture.web.evaluateJavaScript(AuthenticationScripts.formReady) as? Bool
            precondition(ready == true, "Official form fixture not ready")
            let password = "a'\"\\\n<script>test</script>"
            let refused = try await fixture.web.callAsyncJavaScript(AuthenticationScripts.submit, arguments: ["account":"demo", "password":password, "agreed":false], in: nil, contentWorld: .page) as? Bool
            precondition(refused == false)
            let submitted = try await fixture.web.callAsyncJavaScript(AuthenticationScripts.submit, arguments: ["account":"demo", "password":password, "agreed":true], in: nil, contentWorld: .page) as? Bool
            let value = try await fixture.web.evaluateJavaScript("document.querySelector('#pwd').value") as? String
            let count = try await fixture.web.evaluateJavaScript("submitted") as? Int
            precondition(submitted == true && value == password.replacingOccurrences(of: "\n", with: "") && count == 1)
            print("AUTH_CHECK PASS: consent required, explicit submission once, safely passed special characters")
            try await fixture.load("<html><body><div id='tiles'></div></body></html>", at: URL(string: "http://ecard.hbust.edu.cn/plat?name=loginTransit")!)
            _ = try await fixture.web.evaluateJavaScript(AuthenticationScripts.portal)
            _ = try await fixture.web.evaluateJavaScript(#"""
            window.entryClicks=0; window.otherClicks=0;
            setTimeout(() => {
              const host=document.querySelector('#tiles');
              host.innerHTML='<div onclick="otherClicks++">卡片充值</div><div onclick="entryClicks++"><span>宿舍电费充值</span></div>';
            }, 500);
            """#)
            try await Task.sleep(for: .seconds(2))
            _ = try await fixture.web.evaluateJavaScript(AuthenticationScripts.portal)
            let clicks = try await fixture.web.evaluateJavaScript("[entryClicks,otherClicks]") as? [Int]
            precondition(clicks == [1,0], "Delayed SPA tile should open exactly once")
            print("AUTH_CHECK PASS: asynchronous non-link tile opens once; card recharge untouched")
            try await fixture.load("<html><body><button onclick='window.clicked=true'>宿舍电费充值</button></body></html>", at: URL(string: "https://ecard.hbust.edu.cn.evil.invalid/plat")!)
            _ = try await fixture.web.evaluateJavaScript(AuthenticationScripts.portal)
            let blocked = try await fixture.web.evaluateJavaScript("window.clicked === undefined") as? Bool
            precondition(blocked == true)
            print("AUTH_CHECK PASS: no automation on lookalike domain")
            try await fixture.load("<html><body><div id='app'></div></body></html>", at: CampusCardScripts.portalURL)
            _ = try await fixture.web.evaluateJavaScript("document.querySelector('#app').__vue__ = {$ecardConfig:{type:'0'},$store:{state:{token:'test'}},$api:{get:async()=>({data:{card:[{db_balance:900,unsettle_amount:100,elec_accamt:250}]}})}}")
            let cardReady = try await fixture.web.evaluateJavaScript(CampusCardScripts.ready) as? Bool
            let balance = try await fixture.web.callAsyncJavaScript(CampusCardScripts.read, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
            precondition(cardReady == true && balance?["amount"] as? Double == 12.5 && balance?["count"] as? Int == 1)
            print("CAMPUS_CHECK PASS: native WebKit promise bridge returns correct yuan balance")
            _ = try await fixture.web.evaluateJavaScript("sessionStorage.setItem('campus-handoff-test', 'retained')")
            let freshPage = Fixture()
            try await freshPage.load("<html><body>new page</body></html>", at: CampusCardScripts.portalURL)
            let missing = try await freshPage.web.evaluateJavaScript("sessionStorage.getItem('campus-handoff-test') === null") as? Bool
            precondition(missing == true, "Separate WebViews should not share sessionStorage")
            let campus = CampusCardViewController(model: AppModel())
            campus.loadViewIfNeeded()
            campus.adoptPortal(fixture.web)
            precondition(campus.portalForVerification === fixture.web)
            let retained = try await campus.portalForVerification.evaluateJavaScript("sessionStorage.getItem('campus-handoff-test')") as? String
            precondition(retained == "retained", "Login handoff must preserve origin sessionStorage")
            print("CAMPUS_CHECK PASS: reproduced lost session in new WebView; production handoff retains session")
            print("AUTH_CHECK COMPLETE")
        } catch { preconditionFailure("AUTH_CHECK FAILED: \(error)") }
    }
}
#endif
