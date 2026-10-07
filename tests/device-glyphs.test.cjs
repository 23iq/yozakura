const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const g = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/controls/DeviceGlyphs.js'));
const labels = { connected: 'Connected', paired: 'Paired', notPaired: 'Not paired' };

test('wifiGlyph: strength bands, junk is the weakest', () => {
    assert.equal(g.wifiGlyph(92), 'wifiHigh');
    assert.equal(g.wifiGlyph(64), 'wifiMedium');
    assert.equal(g.wifiGlyph(41), 'wifiLow');
    assert.equal(g.wifiGlyph(10), 'wifiNone');
    assert.equal(g.wifiGlyph(undefined), 'wifiNone');
});

test('bluetoothGlyph: BlueZ icon names, else bluetooth', () => {
    assert.equal(g.bluetoothGlyph('audio-headset'), 'headphones');
    assert.equal(g.bluetoothGlyph('audio-headphones'), 'headphones');
    assert.equal(g.bluetoothGlyph('input-keyboard'), 'keyboard');
    assert.equal(g.bluetoothGlyph('input-gaming'), 'gamepad');
    assert.equal(g.bluetoothGlyph('audio-speakers'), 'speaker');
    assert.equal(g.bluetoothGlyph(''), 'bluetooth');
    assert.equal(g.bluetoothGlyph(null), 'bluetooth');
});

test('bluetoothStatus: state then battery when known', () => {
    assert.equal(g.bluetoothStatus(true, true, 72.4, labels), 'Connected · 72%');
    assert.equal(g.bluetoothStatus(false, true, -1, labels), 'Paired');
    assert.equal(g.bluetoothStatus(false, false, undefined, labels), 'Not paired');
});
