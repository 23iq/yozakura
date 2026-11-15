// The keyboard drawn on the Keys destination (modules/settings/stages/KeyDeck.js):
// its rows, which caps a shortcut lights, the keys of a layout switch.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const D = loadLibrary(path.join(__dirname, '..', 'modules/settings/stages/KeyDeck.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('every row is as wide as the others', () => {
    for (const row of D.ROWS) {
        const units = row.reduce((s, k) => s + k[2], 0);
        assert.equal(units, D.UNITS, row.map(k => k[0]).join(' '));
    }
});

test('a combo lights its modifiers and its key, by the names binds use', () => {
    assert.deepEqual(plain(D.lit({ modifiers: ['super', 'shift'], key: 'Return' })), ['SUPER', 'SHIFT', 'return']);
    assert.deepEqual(plain(D.lit({ modifiers: ['SUPER'], key: '/' })), ['SUPER', 'slash']);
    assert.deepEqual(plain(D.lit({ modifiers: [], key: 'SUPER_L' })), ['SUPER']);
    assert.deepEqual(plain(D.lit(null)), []);
    const ids = new Set(D.ROWS.flat().map(k => k[0]));
    for (const k of ['SUPER', 'SHIFT', 'return', 'slash', 'space', 'tab', 'e'])
        assert.ok(ids.has(k), `${k} is a cap`);
});

test('a layout switch lights its keys', () => {
    assert.deepEqual(plain(D.switchKeys('alt_shift')), ['ALT', 'SHIFT']);
    assert.deepEqual(plain(D.switchKeys('super_space')), ['SUPER', 'space']);
    assert.deepEqual(plain(D.switchKeys('caps')), ['caps_lock']);
    assert.deepEqual(plain(D.switchKeys('none')), []);
});
