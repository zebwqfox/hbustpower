// Offline contract tests for the exact read-only script embedded in Swift.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const swift = fs.readFileSync(path.join(__dirname, '../HBUSTPowerIOS/Services/CampusCardScripts.swift'), 'utf8');
const script = swift.match(/static let read = #"""([\s\S]*?)"""#/)[1];
async function read(type, cards, host = 'ecard.hbust.edu.cn', token = 'offline-test') {
  let calls = 0;
  const context = {
    location: {protocol: 'http:', hostname: host, pathname: '/plat'},
    document: {querySelector: () => ({__vue__: {
      $ecardConfig: {type}, $store: {state: {token}},
      $api: {get: async route => { assert.equal(route, '/berserker-app/ykt/tsm/getCampusCards'); calls++; return {data: {card: cards}}; }}
    }})}
  };
  const result = await vm.runInNewContext(`(async () => {${script}})()`, context);
  assert.equal(calls, 1);
  return result;
}
(async () => {
  const card = {db_balance: 900, unsettle_amount: 100, elec_accamt: 250};
  assert.equal((await read('0', [card])).amount, 12.5);
  assert.equal((await read('1', [card])).amount, 2.5);
  assert.equal((await read('2', [card])).amount, 10);
  const multi = await read('0', [card, card]); assert.equal(multi.count, 2); assert.equal(multi.amount, 25);
  assert.equal((await read('2', [{db_balance: 0, unsettle_amount: 0}])).amount, 0);
  assert.equal((await read('2', [{db_balance: -100, unsettle_amount: 0}])).amount, -1);
  await assert.rejects(read('0', []));
  await assert.rejects(read('0', [{db_balance: null, unsettle_amount: 0, elec_accamt: 0}]));
  await assert.rejects(read('0', [{...card, elec_accamt: 'not-a-number'}]));
  await assert.rejects(read('0', [card], 'ecard.hbust.edu.cn.evil.example'));
  await assert.rejects(read('0', [card], 'ecard.hbust.edu.cn', ''));
  await assert.rejects(read('unsupported', [card]));
  console.log('CAMPUS_CHECK PASS: 12 read-only, origin, session, cent/yuan and missing-data checks');
})().catch(error => { console.error(error); process.exitCode = 1; });
