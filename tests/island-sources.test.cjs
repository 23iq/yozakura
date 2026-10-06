const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary(path.join(__dirname, '../modules/services/activities/IslandSources.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('battery fires on charging start and on crossing the low threshold, once', () => {
    const st = (pct, charging) => ({ available: true, percent: pct, charging });
    assert.equal(S.batteryEvent(null, st(50, false), 20), null, 'no event on the first sample');
    assert.deepEqual(plain(S.batteryEvent(st(50, false), st(50, true), 20)), { kind: 'charging', percent: 50 });
    assert.equal(S.batteryEvent(st(50, true), st(51, true), 20), null, 'still charging');
    assert.deepEqual(plain(S.batteryEvent(st(21, false), st(20, false), 20)), { kind: 'low', percent: 20 });
    assert.equal(S.batteryEvent(st(20, false), st(19, false), 20), null, 'already low');
    assert.equal(S.batteryEvent(st(25, true), st(15, true), 20), null, 'low while charging is fine');
    assert.equal(S.batteryEvent(st(50, false), { available: false }, 20), null);
});
test('battery activity: stable id, charging/low look', () => {
    const a = plain(S.batteryActivity({ kind: 'low', percent: 12.4 }, { low: 'Low battery', charging: 'Charging' }));
    assert.equal(a.id, 'battery');
    assert.equal(a.source, 'battery');
    assert.equal(a.label, '12%');
    assert.equal(a.color, 'error');
    assert.equal(a.detail, 'Low battery');
    const c = plain(S.batteryActivity({ kind: 'charging', percent: 80 }, {}));
    assert.equal(c.id, 'battery', 'same id so a new event updates in place');
    assert.equal(c.color, 'primary');
    assert.equal(c.progress, 0.8);
});
test('bluetooth diff reports connects and disconnects with battery when known', () => {
    const prev = [{ address: 'A', name: 'Buds', battery: 70 }];
    const cur = [{ address: 'B', name: 'Mouse', battery: -1 }];
    const ev = plain(S.bluetoothEvents(prev, cur));
    assert.deepEqual(ev, [
        { kind: 'connected', name: 'Mouse', battery: -1, address: 'B' },
        { kind: 'disconnected', name: 'Buds', battery: 70, address: 'A' }
    ]);
    assert.deepEqual(plain(S.bluetoothEvents(cur, cur)), []);
    assert.deepEqual(plain(S.bluetoothEvents(null, null)), []);
    const a = plain(S.bluetoothActivity(ev[1], { connected: 'Connected', disconnected: 'Disconnected' }));
    assert.equal(a.id, 'bluetooth');
    assert.equal(a.label, '70%');
    assert.equal(a.detail, 'Buds · Disconnected');
    assert.equal(plain(S.bluetoothActivity(ev[0], {})).label, 'Mouse');
});
test('osd activity: one id for every kind, level ring, muted state, device name', () => {
    const v = plain(S.osdActivity('volume', 0.47, false, '', {}));
    assert.equal(v.id, 'osd');
    assert.equal(v.indicator, 'ring');
    assert.equal(v.progress, 0.47);
    assert.equal(v.label, '47%');
    const m = plain(S.osdActivity('volume', 0.47, true, '', { muted: 'Muted' }));
    assert.equal(m.label, 'Muted');
    assert.equal(m.color, 'error');
    assert.equal(plain(S.osdActivity('volume', 1.7, false, '', {})).progress, 1);
    assert.equal(plain(S.osdActivity('brightness', -2, false, '', {})).label, '0%');
    assert.equal(plain(S.osdActivity('device', 0.5, false, 'Headphones', {})).detail, 'Headphones');
});
test('extras jobs become percent transfers for the transfers panel', () => {
    const jobs = { a: { job: 'j1', kind: 'install', entries: ['kitty', 'fish'], state: 'running', percent: 40, phase: 'Downloading' },
                   b: { job: 'j2', kind: 'install', entries: ['mpv'], state: 'queued', percent: 0 },
                   c: { job: 'j3', state: 'done', percent: 100 } };
    const t = plain(S.extrasTransfers(jobs, id => id.toUpperCase(), 1000));
    assert.equal(t.length, 2);
    assert.equal(t[0].id, 'extras:j1');
    assert.equal(t[0].source, 'extras');
    assert.equal(t[0].units, 'percent');
    assert.equal(t[0].processed, 40);
    assert.equal(t[0].total, 100);
    assert.equal(t[0].title, 'KITTY · FISH');
    assert.equal(t[0].detail, 'Downloading');
    assert.equal(t[1].state, 'queued');
    assert.deepEqual(plain(S.extrasTransfers(null, null, 0)), []);
});
