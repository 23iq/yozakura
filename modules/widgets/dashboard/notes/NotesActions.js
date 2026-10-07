.pragma library

// Keyboard actions of the notes tab, on the tab's state and methods (`tab`
// is the NotesTab, or a stand-in with the same members in tests).
// Unit tested in tests/notes-actions.test.cjs.

// Enter: confirm / cancel delete or rename, run the highlighted option of an
// expanded row, expand the create row (Rich text / Markdown) or open the
// selected note.
function activate(tab) {
    if (tab.deleteMode) {
        if (tab.deleteButtonIndex === 1)
            tab.confirmDeleteNote();
        else
            tab.cancelDeleteMode();
        return;
    }
    if (tab.renameMode) {
        if (tab.renameButtonIndex === 1)
            tab.confirmRenameNote();
        else
            tab.cancelRenameMode();
        return;
    }
    if (tab.expandedItemIndex >= 0) {
        runOption(tab, tab.filteredNotes[tab.expandedItemIndex], tab.selectedOptionIndex);
        tab.expandedItemIndex = -1;
        tab.selectedOptionIndex = 0;
        return;
    }
    var note = tab.filteredNotes[tab.selectedIndex];
    if (tab.selectedIndex < 0 || !note)
        return;
    if (note.isCreateButton || note.isCreateSpecificButton) {
        tab.expandedItemIndex = tab.selectedIndex;
        tab.selectedOptionIndex = 0;
        tab.keyboardNavigation = true;
    } else {
        tab.openNoteInEditor(note.id);
    }
}

// Option `i` of an expanded row: Rich text / Markdown on the create row,
// Edit / Rename / Delete on a note.
function runOption(tab, note, i) {
    if (!note)
        return;
    if (note.isCreateButton) {
        if (i === 0 || i === 1) {
            tab.expandedItemIndex = -1;
            tab.createNewNote(note.noteNameToCreate || "", i === 1);
        }
    } else if (i === 0) {
        tab.openNoteInEditor(note.id);
    } else if (i === 1) {
        tab.enterRenameMode(note.id);
    } else if (i === 2) {
        tab.enterDeleteMode(note.id);
    }
}

// A key on the tab in delete / rename mode: Left / Right pick cancel or
// confirm, Enter / Space run it (delete; the rename field takes Enter),
// Escape cancels. Returns whether the key was used.
function modeKey(tab, key, keys) {
    if (!tab.deleteMode && !tab.renameMode)
        return false;
    var del = tab.deleteMode;
    if (key === keys.left || key === keys.right) {
        var i = key === keys.left ? 0 : 1;
        if (del)
            tab.deleteButtonIndex = i;
        else
            tab.renameButtonIndex = i;
    } else if (key === keys.escape) {
        if (del)
            tab.cancelDeleteMode();
        else
            tab.cancelRenameMode();
    } else if (del && (key === keys.enter || key === keys.space)) {
        if (tab.deleteButtonIndex === 0)
            tab.cancelDeleteMode();
        else
            tab.confirmDeleteNote();
    } else {
        return false;
    }
    return true;
}
