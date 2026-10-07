const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const A = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/notes/NotesActions.js'));
const KEYS = { left: 1, right: 2, escape: 3, enter: 4, space: 5 };

// A stand-in NotesTab recording the methods called.
function fakeTab(state) {
    const calls = [];
    const rec = name => (...args) => calls.push([name, ...args]);
    return Object.assign({
        calls,
        deleteMode: false, renameMode: false, deleteButtonIndex: 0, renameButtonIndex: 1,
        expandedItemIndex: -1, selectedOptionIndex: 0, selectedIndex: -1, keyboardNavigation: false,
        filteredNotes: [{ id: '__create__', isCreateButton: true, noteNameToCreate: 'x' }, { id: 'a' }],
        confirmDeleteNote: rec('confirmDelete'), cancelDeleteMode: rec('cancelDelete'),
        confirmRenameNote: rec('confirmRename'), cancelRenameMode: rec('cancelRename'),
        openNoteInEditor: rec('open'), enterRenameMode: rec('rename'), enterDeleteMode: rec('delete'),
        createNewNote: rec('create'),
    }, state);
}

test('Enter confirms or cancels delete / rename', () => {
    let t = fakeTab({ deleteMode: true, deleteButtonIndex: 1 });
    A.activate(t);
    assert.deepEqual(t.calls, [['confirmDelete']]);
    t = fakeTab({ renameMode: true, renameButtonIndex: 0 });
    A.activate(t);
    assert.deepEqual(t.calls, [['cancelRename']]);
});

test('Enter on a row opens the note or expands the create row', () => {
    let t = fakeTab({ selectedIndex: 1 });
    A.activate(t);
    assert.deepEqual(t.calls, [['open', 'a']]);
    t = fakeTab({ selectedIndex: 0 });
    A.activate(t);
    assert.equal(t.expandedItemIndex, 0);
    assert.equal(t.keyboardNavigation, true);
    t = fakeTab({ selectedIndex: -1 });
    A.activate(t);
    assert.deepEqual(t.calls, []);
});

test('Enter runs the highlighted option and collapses', () => {
    let t = fakeTab({ expandedItemIndex: 0, selectedOptionIndex: 1 });
    A.activate(t);
    assert.deepEqual(t.calls, [['create', 'x', true]]);
    assert.equal(t.expandedItemIndex, -1);
    for (const [i, name] of [[0, 'open'], [1, 'rename'], [2, 'delete']]) {
        t = fakeTab({ expandedItemIndex: 1, selectedOptionIndex: i });
        A.activate(t);
        assert.deepEqual(t.calls, [[name, 'a']]);
        assert.equal(t.selectedOptionIndex, 0);
    }
});

test('mode keys pick and run cancel / confirm', () => {
    let t = fakeTab({});
    assert.equal(A.modeKey(t, KEYS.left, KEYS), false);
    t = fakeTab({ deleteMode: true });
    assert.equal(A.modeKey(t, KEYS.right, KEYS), true);
    assert.equal(t.deleteButtonIndex, 1);
    A.modeKey(t, KEYS.space, KEYS);
    assert.deepEqual(t.calls, [['confirmDelete']]);
    t = fakeTab({ renameMode: true });
    A.modeKey(t, KEYS.left, KEYS);
    assert.equal(t.renameButtonIndex, 0);
    assert.equal(A.modeKey(t, KEYS.enter, KEYS), false);
    A.modeKey(t, KEYS.escape, KEYS);
    assert.deepEqual(t.calls, [['cancelRename']]);
});
