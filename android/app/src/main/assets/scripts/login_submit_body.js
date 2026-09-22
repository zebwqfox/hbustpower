// Copied verbatim from iOS 1.7.1 Services/AuthenticationScripts.swift (submit).
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
