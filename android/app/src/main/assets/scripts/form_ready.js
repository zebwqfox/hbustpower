// Copied verbatim from iOS 1.7.1 Services/AuthenticationScripts.swift (formReady).
(() => location.protocol === 'https:' && location.hostname === 'passport2.chaoxing.com' && location.pathname === '/mlogin'
  && !!document.querySelector('#phone') && !!document.querySelector('#pwd')
  && typeof loginByPhoneAndPwd === 'function' && typeof hasAgreePolicy === 'function')()
