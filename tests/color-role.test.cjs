// Model of the settings `color-role` control (modules/settings/controls/ColorRoleModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '..', 'modules/settings/controls/ColorRoleModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('values round-trip as stops', () => {
    assert.deepEqual(plain(M.toStops('primary')), ['primary']);
    assert.deepEqual(plain(M.toStops({ length: 2, 0: 'primary', 1: 'tertiary@0.5' })), ['primary', 'tertiary@0.5']);
    assert.deepEqual(plain(M.toStops(undefined)), []);
    assert.equal(M.fromStops(['shadow'], false), 'shadow');
    assert.deepEqual(plain(M.fromStops(['a', 'b'], true)), ['a', 'b']);
});

test('role and alpha edits keep each other', () => {
    const s = ['surfaceBright@0.6', 'primary'];
    assert.deepEqual(plain(M.setRole(s, 0, 'tertiary')), ['tertiary@0.6', 'primary']);
    assert.deepEqual(plain(M.setAlpha(s, 1, 0.25)), ['surfaceBright@0.6', 'primary@0.25']);
    assert.deepEqual(plain(M.setAlpha(s, 0, 1)), ['surfaceBright', 'primary']);
    assert.equal(M.roleOf('#ff0000@0.5'), '#ff0000');
    assert.equal(M.alphaOf('primary'), 1);
});

test('stops can be added up to the limit and never all removed', () => {
    let s = ['primary'];
    s = M.addStop(s, 0);
    assert.deepEqual(plain(s), ['primary', 'primary']);
    s = M.addStop(M.addStop(M.addStop(s, 1), 0), 0);
    assert.equal(s.length, M.MAX_STOPS);
    assert.deepEqual(plain(M.removeStop(['x'], 0)), ['x']);
    assert.deepEqual(plain(M.removeStop(['x', 'y', 'z'], 1)), ['x', 'z']);
    for (const r of M.ROLES) assert.equal(typeof r, 'string');
});
