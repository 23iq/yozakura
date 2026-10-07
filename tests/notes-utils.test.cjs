const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const U = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/notes/notes_utils.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const notes = [{ id: 'a', title: 'Alpha' }, { id: 'b', title: 'Beta' }];

test('list entries: create row first, filtered notes after', () => {
    const all = plain(U.listEntries(notes, '', true));
    assert.deepEqual(all.map(n => n.id), ['__create__', 'a', 'b']);
    assert.equal(all[0].title, 'Create new note');
    assert.equal(all[0].isCreateSpecificButton, false);
    const found = plain(U.listEntries(notes, 'alp', true));
    assert.deepEqual(found.map(n => n.id), ['__create__', 'a']);
    assert.equal(found[0].title, 'Create note "alp"');
    assert.equal(found[0].noteNameToCreate, 'alp');
    assert.equal(plain(U.listEntries(notes, 'beta', true))[0].isCreateSpecificButton, false);
    assert.deepEqual(plain(U.listEntries(notes, '', false)).map(n => n.id), ['a', 'b']);
});

test('delete prompt cuts long titles', () => {
    assert.equal(U.deletePrompt('Alpha'), 'Delete "Alpha"?');
    assert.equal(U.deletePrompt('a'.repeat(25)), 'Delete "' + 'a'.repeat(20) + '..."?');
    assert.equal(U.deletePrompt(undefined), 'Delete ""?');
});

test('row heights and scrolling', () => {
    assert.equal(U.optionCount({ isCreateButton: true }), 2);
    assert.equal(U.optionCount(notes[0]), 3);
    assert.equal(U.rowHeight(notes[0], false, 48, 36, 4), 48);
    assert.equal(U.rowHeight(notes[0], true, 48, 36, 4), 48 + 4 + 108 + 4);
    assert.equal(U.scrollToShow(0, 48, 100, 200, 500), 0);
    assert.equal(U.scrollToShow(120, 48, 100, 200, 500), -1);
    assert.equal(U.scrollToShow(280, 60, 100, 200, 500), 140);
    assert.equal(U.scrollToShow(480, 60, 100, 200, 500), 300);
});
