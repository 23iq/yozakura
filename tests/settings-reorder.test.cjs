// The reorderable lists of the settings editors (modules/settings/editors/
// ReorderModel.js under ReorderList.qml): the slot a drag lands on, the index
// a drop and a key press give, only the movable rows moving.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/ReorderModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('a drag lands on the slot boundary nearest the pointer, among the movable rows', () => {
    assert.equal(M.slotAt(0, 40, 5), 0);
    assert.equal(M.slotAt(19, 40, 5), 0);
    assert.equal(M.slotAt(21, 40, 5), 1);
    assert.equal(M.slotAt(-80, 40, 5), 0, 'above the list: the first slot');
    assert.equal(M.slotAt(1000, 40, 5), 5, 'past the movable rows: after the last of them');
    assert.equal(M.slotAt(1000, 40, 3), 3, 'fixed rows (the launcher tabs) are no slot');
});

test('a dropped row leaves its place first', () => {
    assert.equal(M.dropIndex(1, 0), 0);
    assert.equal(M.dropIndex(1, 1), 1, 'on its own slot: stays');
    assert.equal(M.dropIndex(1, 2), 1, 'just under itself: stays');
    assert.equal(M.dropIndex(1, 4), 3);
    assert.equal(M.dropIndex(0, 5), 4, 'to the end');
});

test('Up / Down move one place, never past the movable rows', () => {
    assert.equal(M.stepIndex(2, -1, 5), 1);
    assert.equal(M.stepIndex(2, 1, 5), 3);
    assert.equal(M.stepIndex(0, -1, 5), 0);
    assert.equal(M.stepIndex(4, 1, 5), 4);
    assert.equal(M.stepIndex(2, 1, 3), 2, 'the last movable row stays');
    assert.equal(M.stepIndex(4, -1, 3), 4, 'a fixed row does not move');
});

test('moved: a copy with the key at its new index', () => {
    const keys = ['a', 'b', 'c', 'd'];
    assert.deepEqual(plain(M.moved(keys, 'a', 2)), ['b', 'c', 'a', 'd']);
    assert.deepEqual(plain(M.moved(keys, 'd', 0)), ['d', 'a', 'b', 'c']);
    assert.deepEqual(plain(M.moved(keys, 'x', 0)), keys, 'an unknown key changes nothing');
    assert.deepEqual(keys, ['a', 'b', 'c', 'd'], 'the input is not changed');
});
