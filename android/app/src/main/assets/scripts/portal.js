// Copied verbatim from iOS 1.7.1 Services/AuthenticationScripts.swift (portal).
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
