// The connect pages' helpers (modules/settings/connect/ConnectModel.js):
// signal bars, what a network / device row says, which item the details
// card shows, device glyphs.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const C = loadLibrary(path.join(__dirname, '..', 'modules/settings/connect/ConnectModel.js'));
const tr = k => ({ 'prefs.net.secured': 'Secured', 'prefs.net.open': 'Open', 'prefs.bt.connected': 'Connected',
    'prefs.bt.paired': 'Paired', 'prefs.bt.new': 'Nearby', 'prefs.bt.connecting': 'Connecting' })[k] || k;

test('signal strength reads as 0..4 bars', () => {
    assert.deepEqual([0, 10, 31, 56, 81, 100].map(C.bars), [0, 1, 2, 3, 4, 4]);
    assert.equal(C.bars(undefined), 0);
});

test('a network row says its band and whether it is secured', () => {
    assert.equal(C.wifiLine({ frequency: 5180, security: 'WPA2' }, tr), '5 GHz · Secured');
    assert.equal(C.wifiLine({ frequency: 2412, security: '' }, tr), '2.4 GHz · Open');
    assert.equal(C.wifiLine({ frequency: 2412, security: '--' }, tr), '2.4 GHz · Open');
    assert.equal(C.wifiLine(null, tr), '');
});

test('the details card shows the picked item, else the active one, else the first', () => {
    const list = [{ ssid: 'a' }, { ssid: 'b', active: true }, { ssid: 'c' }];
    assert.equal(C.pick(list, 'ssid', 'c', 'active').ssid, 'c');
    assert.equal(C.pick(list, 'ssid', '', 'active').ssid, 'b');
    assert.equal(C.pick(list, 'ssid', 'gone', 'active').ssid, 'b', 'a picked item that left falls back');
    assert.equal(C.pick([{ ssid: 'x' }], 'ssid', '', 'active').ssid, 'x');
    assert.equal(C.pick([], 'ssid', 'a', 'active'), null);
});

test('devices: glyph from the icon name, state line with battery', () => {
    assert.equal(C.deviceGlyph('audio-headset'), 'headphones');
    assert.equal(C.deviceGlyph('input-mouse'), 'mouse');
    assert.equal(C.deviceGlyph('input-gaming'), 'gamepad');
    assert.equal(C.deviceGlyph(''), 'bluetooth');
    assert.equal(C.deviceLine({ connected: true, battery: 64 }, tr), 'Connected · 64 %');
    assert.equal(C.deviceLine({ connected: false, paired: true, battery: 64 }, tr), 'Paired');
    assert.equal(C.deviceLine({ paired: false, battery: -1 }, tr), 'Nearby');
    assert.equal(C.percent(0.755), '76 %');
});
