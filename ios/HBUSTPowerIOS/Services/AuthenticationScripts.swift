import Foundation

/// The official page remains responsible for encryption, authentication and challenges.
enum AuthenticationScripts {
    static let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    static func isLoginForm(_ url: URL?) -> Bool {
        url?.scheme == "https" && url?.host?.lowercased() == "passport2.chaoxing.com" && url?.path == "/mlogin"
    }

    static func isCampusPortal(_ url: URL?) -> Bool {
        guard let url, ["http", "https"].contains(url.scheme ?? "") else { return false }
        return url.host?.lowercased() == "ecard.hbust.edu.cn" && (url.path == "/plat" || url.path.hasPrefix("/plat/"))
    }

    static func isSchoolSSO(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "http" && url.host?.lowercased() == "sso.hbust.edu.cn"
            && url.port == 28000 && (url.path == "/login" || url.path.hasPrefix("/login/"))
    }

    static func isSchoolSSOEntry(_ url: URL?) -> Bool {
        guard let url, url.scheme == "http", url.host?.lowercased() == "ecard.hbust.edu.cn",
              url.path == "/berserker-auth/cas/commonoauth2/redirect",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let resultURLs = components.queryItems?.filter { $0.name == "resultUrl" } ?? []
        return resultURLs.count == 1 && resultURLs.first?.value == "http://ecard.hbust.edu.cn/plat?name=loginTransit"
    }

    static func isSchoolSSODenialMessage(_ text: String) -> Bool {
        text.contains("服务大厅未授权")
    }

    static let schoolSSOObserver = #"""
    (() => {
      if (window.top !== window || location.protocol !== 'http:' || location.hostname !== 'sso.hbust.edu.cn'
        || location.port !== '28000' || !(location.pathname === '/login' || location.pathname.startsWith('/login/'))
        || window.__powerSchoolSSOObserver) return;
      window.__powerSchoolSSOObserver = true;
      let reported = false;
      const check = () => {
        if (reported || !(document.body?.innerText || '').includes('服务大厅未授权')) return;
        reported = true;
        observer.disconnect();
        window.webkit?.messageHandlers?.powerAuth?.postMessage('school-sso-service-denied');
      };
      const observer = new MutationObserver(check);
      observer.observe(document.documentElement, {childList:true, subtree:true, characterData:true});
      setTimeout(() => observer.disconnect(), 30000);
      check();
    })();
    """#

    static let formReady = #"""
    (() => location.protocol === 'https:' && location.hostname === 'passport2.chaoxing.com' && location.pathname === '/mlogin'
      && !!document.querySelector('#phone') && !!document.querySelector('#pwd')
      && typeof loginByPhoneAndPwd === 'function' && typeof hasAgreePolicy === 'function')()
    """#

    // account/password are WK callAsyncJavaScript arguments, never interpolated into source.
    static let submit = #"""
    if (location.protocol !== 'https:' || location.hostname !== 'passport2.chaoxing.com' || location.pathname !== '/mlogin') return false;
    const phone = document.querySelector('#phone'), pwd = document.querySelector('#pwd');
    const consent = document.querySelector('.prompt-info .checkBox');
    const button = document.querySelector('button[onclick*="loginByPhoneAndPwd"]');
    if (!phone || !pwd || !consent || !button || typeof loginByPhoneAndPwd !== 'function' || typeof hasAgreePolicy !== 'function' || agreed !== true) return false;
    phone.value = account; pwd.value = password;
    for (const field of [phone, pwd]) {
      field.dispatchEvent(new Event('input', {bubbles:true}));
      field.dispatchEvent(new Event('change', {bubbles:true}));
    }
    if (!consent.classList.contains('checkedBox')) consent.click();
    if (!consent.classList.contains('checkedBox')) return false;
    button.click();
    return true;
    """#

    static let errorText = #"""
    (() => {
      if (location.protocol !== 'https:' || location.hostname !== 'passport2.chaoxing.com' || location.pathname !== '/mlogin') return '';
      return ['phoneMsg','pwdMsg','err-txt'].map(id => document.getElementById(id))
        .filter(el => el && el.getClientRects().length && getComputedStyle(el).display !== 'none')
        .map(el => (el.textContent || '').trim()).filter(Boolean).join('\n').slice(0, 200);
    })()
    """#

    static let portal = #"""
    (() => {
      if (window.top !== window || !['http:', 'https:'].includes(location.protocol)
        || location.hostname !== 'ecard.hbust.edu.cn'
        || !(location.pathname === '/plat' || location.pathname.startsWith('/plat/'))
        || window.__powerElectricityObserver) return;
      window.__powerElectricityObserver = true;
      let opened = false, timer;
      const isElectricityLink = el => {
        const raw = el.getAttribute('href') || el.getAttribute('data-url');
        if (!raw) return false;
        try {
          const url = new URL(raw, location.href);
          return ['http:', 'https:'].includes(url.protocol) && url.hostname === 'ecard.hbust.edu.cn'
            && url.pathname === '/berserker-base/redirect' && url.searchParams.get('appId') === '180';
        } catch { return false; }
      };
      const matches = el => {
        const label = (el.textContent || '').replace(/\s/g, '');
        return ['宿舍电费充值', '电费充值', '用电查询', '电量查询'].includes(label) || isElectricityLink(el);
      };
      const observer = new MutationObserver(() => { clearTimeout(timer); timer = setTimeout(findEntry, 100); });
      function findEntry() {
        if (opened) return;
        const candidates = [...document.querySelectorAll('a,button,[role="button"],[data-url],div,span,p,li')]
          .filter(el => matches(el) && el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden'
            && !el.disabled && el.getAttribute('aria-disabled') !== 'true');
        const entry = candidates.find(el => ![...el.children].some(matches));
        if (!entry) return;
        opened = true;
        observer.disconnect();
        clearInterval(poll);
        entry.click(); // Bubbles to Vue/React tile handlers, including non-anchor cards.
        window.webkit?.messageHandlers?.powerAuth?.postMessage('electricity-entry-opened');
      }
      observer.observe(document.documentElement, {childList:true,subtree:true,attributes:true,attributeFilter:['class','style','href','data-url']});
      const poll = setInterval(findEntry, 500);
      setTimeout(() => { observer.disconnect(); clearInterval(poll); clearTimeout(timer); }, 30000);
      findEntry();
    })();
    """#
}
