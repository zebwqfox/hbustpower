// Copied verbatim from iOS 1.7.1 Services/CampusCardScripts.swift (read).
if (!['http:', 'https:'].includes(location.protocol) || location.hostname !== 'ecard.hbust.edu.cn' || !(location.pathname === '/plat' || location.pathname.startsWith('/plat/'))) throw new Error('origin');
const vm = document.querySelector('#app')?.__vue__;
if (!vm?.$api || !vm?.$ecardConfig || !vm?.$store?.state?.token) throw new Error('authentication');
const response = await vm.$api.get('/berserker-app/ykt/tsm/getCampusCards');
const cards = response?.data?.card;
if (!Array.isArray(cards) || cards.length === 0) throw new Error('missing cards');
const type = String(vm.$ecardConfig.type ?? '');
if (!['0','1','2',''].includes(type)) throw new Error('unsupported card configuration');
const number = value => {
  if (value === null || value === undefined || value === '' || typeof value === 'boolean') throw new Error('missing balance');
  const n = Number(value); if (!Number.isFinite(n)) throw new Error('invalid balance'); return n;
};
let cents = 0;
for (const card of cards) {
  if (type !== '1') cents += number(card.db_balance) + number(card.unsettle_amount);
  if (type !== '2') cents += number(card.elec_accamt);
}
return {amount: cents / 100, count: cards.length};
