import QtQuick
import "notes_utils.js" as NotesUtils

// Applies NotesStore results to the notes tab: the loaded index, a created
// note (listed first, selected and opened), a deleted note, the content of
// the note being opened and a saved title.
QtObject {
    id: storeSync

    // The NotesTab (list + open note state)
    required property var tab
    required property NotesStore store

    readonly property Connections connections: Connections {
        target: storeSync.store

        function onIndexLoaded(notes) {
            storeSync.tab.allNotes = notes;
            storeSync.tab.updateFilteredNotes();
        }

        function onNoteCreated(noteId, title, isMarkdown) {
            const now = NotesUtils.getCurrentTimestamp();
            storeSync.tab.allNotes.unshift({
                id: noteId,
                title: title,
                created: now,
                modified: now,
                isMarkdown: isMarkdown,
                isCreateButton: false
            });
            storeSync.tab.saveNotesOrder();
            // Select the new note, then focus its editor
            storeSync.tab.pendingRenamedNote = noteId;
            storeSync.tab.updateFilteredNotes();
            Qt.callLater(() => storeSync.tab.openNoteInEditor(noteId));
        }

        function onNoteDeleted(noteId) {
            const tab = storeSync.tab;
            tab.allNotes = tab.allNotes.filter(n => n.id !== noteId);
            tab.saveNotesOrder();
            if (tab.currentNoteId === noteId) {
                tab.currentNoteId = "";
                tab.currentNoteContent = "";
                tab.currentNoteTitle = "";
            }
            tab.updateFilteredNotes();
        }

        function onNoteRead(ok, content) {
            const tab = storeSync.tab;
            tab.currentNoteContent = ok ? content : "";
            tab.currentNoteTitle = ok ? (tab.titleOf(tab.currentNoteId) ?? tab.currentNoteTitle) : "";
            tab.editorDirty = false;
            tab.loadingNote = false;
        }

        function onTitleSaved(noteId, title) {
            const note = storeSync.tab.noteById(storeSync.tab.allNotes, noteId);
            if (note) {
                note.title = title;
                note.modified = NotesUtils.getCurrentTimestamp();
            }
            storeSync.tab.updateFilteredNotes();
        }
    }
}
