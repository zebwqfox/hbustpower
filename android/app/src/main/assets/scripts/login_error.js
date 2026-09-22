// Copied verbatim from iOS 1.7.1 Services/AuthenticationScripts.swift (errorText).
(() => {
  if (location.protocol !== 'https:' || location.hostname !== 'passport2.chaoxing.com' || location.pathname !== '/mlogin') return '';
  return ['phoneMsg','pwdMsg','err-txt'].map(id => document.getElementById(id))
    .filter(el => el && el.getClientRects().length && getComputedStyle(el).display !== 'none')
    .map(el => (el.textContent || '').trim()).filter(Boolean).join('\n').slice(0, 200);
})()
