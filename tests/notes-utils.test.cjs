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

test('strict index parse: empty is empty, unreadable is null, fields kept', () => {
    assert.deepEqual(plain(U.parseIndexStrict('')), { order: [], notes: {} });
    assert.equal(U.parseIndexStrict('{"order": ['), null);
    assert.equal(U.parseIndexStrict('[1]'), null);
    assert.deepEqual(plain(U.parseIndexStrict('{"version": 2}')), { version: 2, order: [], notes: {} });
});

test('index entries follow the order and skip ids without metadata', () => {
    const entries = plain(U.indexEntries({ order: ['b', 'x', 'a'], notes: { a: { title: 'A', isMarkdown: true }, b: {} } }));
    assert.deepEqual(entries.map(e => [e.id, e.title, e.isMarkdown]), [['b', 'Untitled', false], ['a', 'A', true]]);
});

test('merge keeps notes added elsewhere, drops removed ones, disk metadata wins', () => {
    const disk = {
        version: 3,
        order: ['ext', 'a', 'gone'],
        notes: { ext: { title: 'Ext', pinned: true }, a: { title: 'A renamed', modified: 'm2', extra: 1 }, gone: { title: 'G' } }
    };
    const tabNotes = [{ id: 'new', title: 'New', created: 'c', modified: 'c', isMarkdown: true },
        { id: 'a', title: 'A', created: 'c0', modified: 'm1' }];
    const out = plain(U.mergeIndex(disk, tabNotes, ['gone']));
    assert.deepEqual(out.order, ['ext', 'new', 'a']);
    assert.equal(out.version, 3);
    assert.deepEqual(out.notes.ext, { title: 'Ext', pinned: true });
    assert.deepEqual(out.notes.new, { title: 'New', created: 'c', modified: 'c', isMarkdown: true });
    assert.deepEqual(out.notes.a, { title: 'A renamed', created: 'c0', modified: 'm2', isMarkdown: false, extra: 1 });
    assert.equal(out.notes.gone, undefined);
});

test('merge over an unreadable index writes the tab notes', () => {
    const out = plain(U.mergeIndex(null, [{ id: 'a', title: 'A', created: '', modified: '' }], []));
    assert.deepEqual(out.order, ['a']);
});

test('updateNote changes a listed note only', () => {
    const idx = { order: ['a'], notes: { a: { title: 'A', modified: 'old' } } };
    const out = U.updateNote(idx, 'a', { title: 'B' });
    assert.equal(out.notes.a.title, 'B');
    assert.notEqual(out.notes.a.modified, 'old');
    assert.equal(U.updateNote(idx, 'zz', { title: 'B' }), null);
    assert.equal(U.updateNote(null, 'a', {}), null);
});
