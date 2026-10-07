import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import "notes_utils.js" as NotesUtils
import "NotesActions.js" as NotesActions

// Notes tab (launcher prefix tab): searchable list of rich text / markdown
// notes on the left, the editor of the selected note on the right.
// State and list actions live here; storage is NotesStore, the list is
// NotesListPanel/NoteListItem, the editors RichTextEditor/MarkdownEditor.
Item {
    id: root
    focus: true

    // Prefix support
    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    // Notes directory configuration
    property string notesDir: Brand.dataDir + "-notes"
    property string indexPath: notesDir + "/index.json"
    property string notesPath: notesDir + "/notes"
    property string noteExtension: ".html"  // Store as HTML for rich text (Markdown uses .md)

    // Search and selection state
    property string searchText: ""
    property int selectedIndex: -1
    property var allNotes: []
    property var filteredNotes: []

    // List model
    ListModel {
        id: notesModel
    }

    // Delete mode state
    property bool deleteMode: false
    property string noteToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0

    // Rename mode state
    property bool renameMode: false
    property string noteToRename: ""
    property string newNoteName: ""
    property int renameSelectedIndex: -1
    property int renameButtonIndex: 0
    property string pendingRenamedNote: ""

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    // Current note content for editor
    property string currentNoteId: ""
    property string currentNoteContent: ""
    property string currentNoteTitle: ""
    property bool currentNoteIsMarkdown: false
    property bool loadingNote: false
    property bool editorDirty: false

    NotesStore {
        id: store
        notesPath: root.notesPath
        indexPath: root.indexPath
        noteExtension: root.noteExtension
    }

    NotesStoreSync {
        store: store
        tab: root
    }

    // Debounce timer for auto-save
    Timer {
        id: saveDebounceTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.currentNoteId && root.editorDirty) {
                root.saveCurrentNote();
            }
        }
    }

    Keys.onEscapePressed: {
        if (root.deleteMode) {
            root.cancelDeleteMode();
        } else if (root.renameMode) {
            root.cancelRenameMode();
        } else {
            Visibilities.setActiveModule("");
        }
    }

    function noteById(notes, noteId) {
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].id === noteId)
                return notes[i];
        }
        return null;
    }

    function isMarkdownNote(noteId) {
        const note = noteById(allNotes, noteId);
        return note ? (note.isMarkdown || false) : false;
    }

    // Title of a note in allNotes (undefined when it is not there)
    function titleOf(noteId) {
        const note = noteById(allNotes, noteId);
        return note ? note.title : undefined;
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && listPanel.listView.count > 0) {
            listPanel.listView.positionViewAtIndex(0, ListView.Beginning);
        }

        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }

        // Load note content when selection changes
        if (selectedIndex >= 0 && selectedIndex < filteredNotes.length) {
            let note = filteredNotes[selectedIndex];
            if (note && !note.isCreateButton) {
                loadNoteContent(note.id);
            } else {
                currentNoteId = "";
                currentNoteContent = "";
                currentNoteTitle = "";
            }
        } else {
            currentNoteId = "";
            currentNoteContent = "";
            currentNoteTitle = "";
        }
    }

    onSearchTextChanged: {
        updateFilteredNotes();
    }

    function focusSearchInput() {
        listPanel.focusSearch();
    }

    // Focus the editor of the open note (Tab from the search field)
    function focusEditor() {
        if (currentNoteId)
            editorPane.focusEditor(currentNoteIsMarkdown);
    }

    function updateFilteredNotes() {
        var newFilteredNotes = NotesUtils.listEntries(allNotes, searchText, !deleteMode && !renameMode);
        filteredNotes = newFilteredNotes;
        listPanel.resetScroll();

        notesModel.clear();
        for (var i = 0; i < newFilteredNotes.length; i++) {
            var note = newFilteredNotes[i];
            notesModel.append({
                noteId: note.id,
                noteData: note
            });
        }

        const list = listPanel.listView;
        if (!deleteMode && !renameMode) {
            if (searchText.length > 0 && newFilteredNotes.length > 0) {
                selectedIndex = 0;
                list.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                list.currentIndex = -1;
            }
        }

        if (pendingRenamedNote !== "") {
            for (let i = 0; i < newFilteredNotes.length; i++) {
                if (newFilteredNotes[i].id === pendingRenamedNote) {
                    selectedIndex = i;
                    list.currentIndex = i;
                    pendingRenamedNote = "";
                    break;
                }
            }
            if (pendingRenamedNote !== "") {
                pendingRenamedNote = "";
            }
        }
    }

    // Enter on the search field (NotesActions.activate)
    function activateSelection() {
        NotesActions.activate(root);
    }

    function enterDeleteMode(noteId) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        noteToDelete = noteId;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        noteToDelete = "";
        deleteButtonIndex = 0;
        listPanel.focusSearch();
        updateFilteredNotes();
        selectedIndex = originalSelectedIndex;
        listPanel.listView.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteNote() {
        if (noteToDelete) {
            // Find if note is markdown to use correct extension
            store.remove(noteToDelete, isMarkdownNote(noteToDelete));
        }
        cancelDeleteMode();
    }

    function enterRenameMode(noteId) {
        renameSelectedIndex = selectedIndex;
        renameMode = true;
        noteToRename = noteId;

        // Find current title
        const title = titleOf(noteId);
        if (title !== undefined)
            newNoteName = title;

        renameButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelRenameMode() {
        renameMode = false;
        noteToRename = "";
        newNoteName = "";
        renameButtonIndex = 1;
        if (pendingRenamedNote === "") {
            listPanel.focusSearch();
            updateFilteredNotes();
            selectedIndex = renameSelectedIndex;
            listPanel.listView.currentIndex = renameSelectedIndex;
        } else {
            listPanel.focusSearch();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenameNote() {
        if (newNoteName.trim() !== "" && noteToRename) {
            pendingRenamedNote = noteToRename;
            store.setTitle(noteToRename, newNoteName.trim());
        }
        cancelRenameMode();
    }

    function createNewNote(title, isMarkdown) {
        store.create(title || "Untitled Note", isMarkdown);
    }

    function loadNoteContent(noteId) {
        if (!noteId || noteId === "__create__")
            return;

        // Save current note before loading new one
        if (currentNoteId && editorDirty) {
            saveCurrentNote();
        }

        // Find note to get isMarkdown flag
        var isMarkdown = isMarkdownNote(noteId);

        loadingNote = true;
        currentNoteId = noteId;
        currentNoteIsMarkdown = isMarkdown;

        store.read(noteId, isMarkdown);
    }

    function saveCurrentNote() {
        if (!currentNoteId || currentNoteId === "__create__")
            return;

        // Get the text content
        var content = editorPane.text(currentNoteIsMarkdown);
        store.write(currentNoteId, currentNoteIsMarkdown, content);
        editorDirty = false;

        // Update modified timestamp
        store.touch(currentNoteId);
    }

    function openNoteInEditor(noteId) {
        // Select the note and focus editor
        var isMarkdown = false;
        for (var i = 0; i < filteredNotes.length; i++) {
            if (filteredNotes[i].id === noteId) {
                selectedIndex = i;
                listPanel.listView.currentIndex = i;
                isMarkdown = filteredNotes[i].isMarkdown || false;
                break;
            }
        }
        Qt.callLater(() => editorPane.focusEditor(isMarkdown));
    }

    // Move the selected note one step up (-1) or down (+1) in the order
    function moveNote(step) {
        let note = filteredNotes[selectedIndex];
        if (note.isCreateButton)
            return;

        // Find in allNotes and swap
        let noteIdx = allNotes.findIndex(n => n.id === note.id);
        let target = noteIdx + step;
        if (noteIdx >= 0 && target >= 0 && target < allNotes.length) {
            allNotes = NotesUtils.moveArrayItem(allNotes, noteIdx, target);
            saveNotesOrder();
            updateFilteredNotes();
            selectedIndex = selectedIndex + step;
            listPanel.listView.currentIndex = selectedIndex;
        }
    }

    function moveNoteUp() {
        if (selectedIndex <= 1)
            return; // Can't move create button or first note
        moveNote(-1);
    }

    function moveNoteDown() {
        if (selectedIndex < 1 || selectedIndex >= filteredNotes.length - 1)
            return;
        moveNote(1);
    }

    function saveNotesOrder() {
        store.writeIndex(allNotes);
    }

    // A text change in an editor marks the open note dirty (debounced save)
    function noteEdited(markdownOnly) {
        if (currentNoteId && !loadingNote && (!markdownOnly || currentNoteIsMarkdown)) {
            editorDirty = true;
            saveDebounceTimer.restart();
        }
    }

    Component.onCompleted: {
        store.init();
    }

    implicitWidth: 400
    implicitHeight: 392

    RowLayout {
        anchors.fill: parent
        spacing: Space.l

        // Left panel: Notes list
        NotesListPanel {
            id: listPanel
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true
            tab: root
            model: notesModel
        }

        Divider {
            vertical: true
            Layout.fillHeight: true
        }

        NoteEditorPane {
            id: editorPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            tab: root
        }
    }

    // Delete / rename mode keys (NotesActions.modeKey)
    Keys.onPressed: event => {
        const keys = {
            left: Qt.Key_Left,
            right: Qt.Key_Right,
            escape: Qt.Key_Escape,
            enter: Qt.Key_Return,
            space: Qt.Key_Space
        };
        if (NotesActions.modeKey(root, event.key, keys))
            event.accepted = true;
    }
}
