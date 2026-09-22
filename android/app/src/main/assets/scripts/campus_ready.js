// Copied verbatim from iOS 1.7.1 Services/CampusCardScripts.swift (ready).
(() => {
  if (!['http:', 'https:'].includes(location.protocol) || location.hostname !== 'ecard.hbust.edu.cn' || !(location.pathname === '/plat' || location.pathname.startsWith('/plat/'))) return false;
  const vm = document.querySelector('#app')?.__vue__;
  return !!(vm?.$api && vm?.$ecardConfig && vm?.$store?.state?.token);
})()
