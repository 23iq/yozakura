import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "notes_utils.js" as NotesUtils

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
    property bool showResults: searchText.length > 0
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

    // Create menu state
    property bool showCreateMenu: false
    property int createMenuSelectedIndex: 0

    NotesStore {
        id: store
        notesPath: root.notesPath
        indexPath: root.indexPath
        noteExtension: root.noteExtension

        onIndexLoaded: notes => {
            root.allNotes = notes;
            root.updateFilteredNotes();
        }

        onNoteCreated: (noteId, title, isMarkdown) => {
            // Add to allNotes and save index
            var newNote = {
                id: noteId,
                title: title,
                created: NotesUtils.getCurrentTimestamp(),
                modified: NotesUtils.getCurrentTimestamp(),
                isMarkdown: isMarkdown,
                isCreateButton: false
            };
            root.allNotes.unshift(newNote);
            root.saveNotesOrder();
            root.updateFilteredNotes();

            // Select the new note
            root.pendingRenamedNote = noteId;
            root.updateFilteredNotes();

            // Focus the editor
            Qt.callLater(() => {
                root.openNoteInEditor(noteId);
            });
        }

        onNoteDeleted: noteId => {
            // Remove from allNotes
            root.allNotes = root.allNotes.filter(n => n.id !== noteId);
            root.saveNotesOrder();

            if (root.currentNoteId === noteId) {
                root.currentNoteId = "";
                root.currentNoteContent = "";
                root.currentNoteTitle = "";
            }

            root.updateFilteredNotes();
        }

        onNoteRead: (ok, content) => {
            if (ok) {
                root.currentNoteContent = content;
                root.currentNoteTitle = root.titleOf(root.currentNoteId) ?? root.currentNoteTitle;
            } else {
                root.currentNoteContent = "";
                root.currentNoteTitle = "";
            }
            root.editorDirty = false;
            root.loadingNote = false;
        }

        onTitleSaved: (noteId, title) => {
            // Update local allNotes
            for (var i = 0; i < root.allNotes.length; i++) {
                if (root.allNotes[i].id === noteId) {
                    root.allNotes[i].title = title;
                    root.allNotes[i].modified = NotesUtils.getCurrentTimestamp();
                    break;
                }
            }
            root.updateFilteredNotes();
        }
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

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= notesModel.count)
            return;

        const list = listPanel.listView;
        var itemY = 0;
        for (var i = 0; i < index; i++) {
            itemY += 48;
        }

        // 3 options: Edit, Rename, Delete
        var listHeight = 36 * 3;
        var expandedHeight = 48 + 4 + listHeight + 8;

        var maxContentY = Math.max(0, list.contentHeight - list.height);
        var viewportTop = list.contentY;
        var viewportBottom = viewportTop + list.height;
        var itemBottom = itemY + expandedHeight;

        if (itemY < viewportTop) {
            list.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            list.contentY = Math.min(itemBottom - list.height, maxContentY);
        }
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

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        listPanel.focusSearch();
        updateFilteredNotes();
    }

    function focusSearchInput() {
        listPanel.focusSearch();
    }

    // Focus the editor of the open note (Tab from the search field)
    function focusEditor() {
        if (currentNoteId) {
            if (currentNoteIsMarkdown) {
                markdownEditor.focusEditor();
            } else {
                richEditor.focusEditor();
            }
        }
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            cancelDeleteMode();
        }
        if (renameMode) {
            cancelRenameMode();
        }
    }

    function updateFilteredNotes() {
        var newFilteredNotes = [];

        var createButtonText = "Create new note";
        var isCreateSpecific = false;
        var noteNameToCreate = "";

        if (searchText.length === 0) {
            newFilteredNotes = allNotes.slice();
        } else {
            newFilteredNotes = NotesUtils.filterNotes(allNotes, searchText);

            let exactMatch = allNotes.find(function (note) {
                return note.title.toLowerCase() === searchText.toLowerCase();
            });

            if (!exactMatch && searchText.length > 0) {
                createButtonText = `Create note "${searchText}"`;
                isCreateSpecific = true;
                noteNameToCreate = searchText;
            }
        }

        if (!deleteMode && !renameMode) {
            newFilteredNotes.unshift({
                id: "__create__",
                title: createButtonText,
                isCreateButton: true,
                isCreateSpecificButton: isCreateSpecific,
                noteNameToCreate: noteNameToCreate,
                icon: "plus"
            });
        }

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

    // Enter on the search field: confirm/cancel delete or rename, run the
    // highlighted option of an expanded row, expand the create row or open
    // the selected note
    function activateSelection() {
        if (deleteMode) {
            if (deleteButtonIndex === 1) {
                confirmDeleteNote();
            } else {
                cancelDeleteMode();
            }
            return;
        }

        if (renameMode) {
            if (renameButtonIndex === 1) {
                confirmRenameNote();
            } else {
                cancelRenameMode();
            }
            return;
        }

        if (expandedItemIndex >= 0) {
            let note = filteredNotes[expandedItemIndex];
            if (note) {
                if (note.isCreateButton) {
                    // Create menu options: Rich Text, Markdown
                    if (selectedOptionIndex >= 0 && selectedOptionIndex < 2) {
                        expandedItemIndex = -1;
                        createNewNote(note.noteNameToCreate || "", selectedOptionIndex === 1);
                    }
                } else {
                    // Note options: Edit, Rename, Delete
                    if (selectedOptionIndex === 0) {
                        openNoteInEditor(note.id);
                    } else if (selectedOptionIndex === 1) {
                        enterRenameMode(note.id);
                    } else if (selectedOptionIndex === 2) {
                        enterDeleteMode(note.id);
                    }
                }
            }
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            return;
        }

        if (selectedIndex >= 0 && selectedIndex < filteredNotes.length) {
            let note = filteredNotes[selectedIndex];
            if (note.isCreateButton || note.isCreateSpecificButton) {
                // Expand to show create options instead of creating directly
                expandedItemIndex = selectedIndex;
                selectedOptionIndex = 0;
                keyboardNavigation = true;
            } else {
                openNoteInEditor(note.id);
            }
        }
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
            updateNoteTitle(noteToRename, newNoteName.trim());
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
        var content = currentNoteIsMarkdown ? markdownEditor.text : richEditor.text;
        store.write(currentNoteId, currentNoteIsMarkdown, content);
        editorDirty = false;

        // Update modified timestamp
        updateNoteModified(currentNoteId);
    }

    function updateNoteTitle(noteId, newTitle) {
        store.setTitle(noteId, newTitle);
    }

    function updateNoteModified(noteId) {
        store.touch(noteId);
    }

    function refreshNotes() {
        store.refresh();
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
        Qt.callLater(() => {
            if (isMarkdown) {
                markdownEditor.focusEditor();
            } else {
                richEditor.focusEditor();
            }
        });
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
        spacing: 8

        // Left panel: Notes list
        NotesListPanel {
            id: listPanel
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true
            tab: root
            model: notesModel
        }

        // Separator
        Separator {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            vert: true
        }

        // Right panel: WYSIWYG Editor (Rich Text mode)
        RichTextEditor {
            id: richEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentNoteId !== "" && !root.currentNoteIsMarkdown
            content: root.currentNoteContent
            onEdited: root.noteEdited(false)
            onEscapePressed: root.focusSearchInput()
        }

        // Right panel: Markdown Editor (split view)
        MarkdownEditor {
            id: markdownEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentNoteId !== "" && root.currentNoteIsMarkdown
            content: root.currentNoteContent
            onEdited: root.noteEdited(true)
            onEscapePressed: root.focusSearchInput()
        }

        // Placeholder when no note selected
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentNoteId === ""

            Text {
                anchors.centerIn: parent
                text: I18n.t("notes.select_or_create")
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.outline
            }
        }
    }

    // Loading overlay (outside RowLayout to avoid anchor warning)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.8)
        visible: root.loadingNote
        radius: Styling.radius(4)

        Text {
            anchors.centerIn: parent
            text: Icons.spinnerGap
            font.family: Icons.font
            font.pixelSize: 24
            color: Colors.overSurface

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: root.loadingNote
            }
        }
    }

    // Root-level key handler for delete/rename mode navigation
    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.deleteButtonIndex === 0) {
                    root.cancelDeleteMode();
                } else {
                    root.confirmDeleteNote();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.renameMode) {
            if (event.key === Qt.Key_Left) {
                root.renameButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.renameButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelRenameMode();
                event.accepted = true;
            }
        }
    }
}
