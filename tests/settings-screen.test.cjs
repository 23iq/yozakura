const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '..', 'modules/settings/SettingsScreen.js'));
const a = { name: 'DP-1' };
const b = { name: 'HDMI-A-1' };

test('byName resolves an output or null', () => {
    assert.strictEqual(S.byName([a, b], 'HDMI-A-1'), b);
    assert.strictEqual(S.byName([a, b], 'eDP-1'), null);
    assert.strictEqual(S.byName([a, b], ''), null);
    assert.strictEqual(S.byName(null, 'DP-1'), null);
});

test('rehomeTarget keeps a window whose output is still there', () => {
    assert.strictEqual(S.rehomeTarget([a, b], b), null);
});

test('rehomeTarget moves to the first output when its own is gone', () => {
    assert.strictEqual(S.rehomeTarget([a], b), a);
    assert.strictEqual(S.rehomeTarget([a], null), a);
});

test('rehomeTarget does nothing without outputs', () => {
    assert.strictEqual(S.rehomeTarget([], b), null);
    assert.strictEqual(S.rehomeTarget(undefined, b), null);
});
