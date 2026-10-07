pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "notes_utils.js" as NotesUtils

// One row of the notes list (or the "create" row) as a kit ListRow: the
// note glyph, title (inline rename editor in rename mode) and modified time;
// in delete / rename mode cancel + confirm as trailing IconButtons. An
// expanded row shows its options (NoteItemOptions) under it. The keyboard
// cursor is the row's `selected` look; a MouseArea on top selects on hover
// and handles left / right clicks (off in delete / rename mode).
Item {
    id: noteItem

    required property string noteId
    required property var noteData
    required property int index
    // The NotesTab (state + actions) and the NotesListPanel showing this row
    required property var tab
    required property var panel

    readonly property var note: noteData
    readonly property bool isInDeleteMode: tab.deleteMode && note.id === tab.noteToDelete
    readonly property bool isInRenameMode: tab.renameMode && note.id === tab.noteToRename
    readonly property bool inMode: isInDeleteMode || isInRenameMode
    readonly property bool isSelected: tab.selectedIndex === index
    readonly property bool isExpanded: index === tab.expandedItemIndex && !inMode

    width: panel.listView.width
    height: panel.rowHeight(note, isExpanded)

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    function select() {
        tab.selectedIndex = index;
        panel.listView.currentIndex = index;
    }

    function toggleOptions(keyboard) {
        if (tab.expandedItemIndex === index) {
            tab.expandedItemIndex = -1;
        } else {
            tab.expandedItemIndex = index;
            select();
        }
        tab.selectedOptionIndex = 0;
        tab.keyboardNavigation = keyboard && tab.expandedItemIndex === index;
    }

    ListRow {
        id: row
        width: parent.width
        height: noteItem.panel.rowH
        selected: noteItem.isSelected || noteItem.inMode
        title: noteItem.isInDeleteMode ? NotesUtils.deletePrompt(noteItem.note.title) : (noteItem.note.title || "Untitled")
        subtitle: noteItem.note.isCreateButton || !noteItem.note.modified ? "" : NotesUtils.formatTimestamp(noteItem.note.modified, I18n.t)
        titleEditor: noteItem.isInRenameMode ? renameEditor : null

        leading: Component {
            Item {
                implicitWidth: Metrics.iconSize
                implicitHeight: Metrics.iconSize

                Text {
                    anchors.centerIn: parent
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("body")
                    color: noteItem.isInDeleteMode ? Colors.error : (noteItem.isSelected || noteItem.inMode ? Type.accent : Type.secondary)
                    text: {
                        if (noteItem.isInDeleteMode)
                            return Icons.trash;
                        if (noteItem.isInRenameMode)
                            return Icons.cursorText;
                        if (noteItem.note.isCreateButton)
                            return Icons.plus;
                        return noteItem.note.isMarkdown ? Icons.markdown : Icons.file;
                    }
                }
            }
        }

        trailing: Component {
            Row {
                spacing: Space.xs
                visible: noteItem.inMode

                Repeater {
                    model: [Icons.cancel, Icons.accept]

                    IconButton {
                        required property string modelData
                        required property int index
                        size: "s"
                        icon: modelData
                        highlighted: (noteItem.isInDeleteMode ? noteItem.tab.deleteButtonIndex : noteItem.tab.renameButtonIndex) === index
                        onHoveredChanged: {
                            if (hovered && !highlighted) {
                                if (noteItem.isInDeleteMode)
                                    noteItem.tab.deleteButtonIndex = index;
                                else
                                    noteItem.tab.renameButtonIndex = index;
                            }
                        }
                        onClicked: {
                            if (noteItem.isInDeleteMode)
                                index === 1 ? noteItem.tab.confirmDeleteNote() : noteItem.tab.cancelDeleteMode();
                            else
                                index === 1 ? noteItem.tab.confirmRenameNote() : noteItem.tab.cancelRenameMode();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: renameEditor
        InlineEdit {
            text: noteItem.tab.newNoteName
            onTextChanged: noteItem.tab.newNoteName = text
            Keys.onPressed: event => {
                const tab = noteItem.tab;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    tab.confirmRenameNote();
                else if (event.key === Qt.Key_Escape)
                    tab.cancelRenameMode();
                else if (event.key === Qt.Key_Left && !event.modifiers)
                    tab.renameButtonIndex = 0;
                else if (event.key === Qt.Key_Right && !event.modifiers)
                    tab.renameButtonIndex = 1;
                else
                    return;
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: row
        hoverEnabled: true
        enabled: !noteItem.tab.deleteMode && !noteItem.tab.renameMode
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            if (noteItem.tab.expandedItemIndex === -1)
                noteItem.select();
        }

        onClicked: mouse => {
            const note = noteItem.note;
            if (mouse.button === Qt.RightButton) {
                if (!note.isCreateButton)
                    noteItem.toggleOptions(false);
            } else if (!noteItem.isExpanded) {
                if (note.isCreateButton || note.isCreateSpecificButton)
                    noteItem.toggleOptions(true);
                else
                    noteItem.tab.openNoteInEditor(note.id);
            }
        }
    }

    NoteItemOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: row.bottom
        anchors.topMargin: Space.xs
        tab: noteItem.tab
        note: noteItem.note
        visible: noteItem.isExpanded
    }
}
