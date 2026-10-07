pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "notes_utils.js" as NotesUtils

// One row of the notes list (or the "create" row): icon, title / inline
// rename field, modified time, delete / rename confirm buttons and the
// expandable options list.
Item {
    id: noteItem

    required property string noteId
    required property var noteData
    required property int index
    // The NotesTab (state + actions) and the list showing this row
    required property var tab
    required property ListView listView

    property var modelData: noteData

    width: noteItem.listView.width
    height: {
        let baseHeight = 48;
        if (noteItem.index === noteItem.tab.expandedItemIndex && !noteItem.isInDeleteMode && !noteItem.isInRenameMode) {
            // 2 options for create button, 3 for regular notes
            var optionCount = noteItem.modelData.isCreateButton ? 2 : 3;
            var listHeight = 36 * optionCount;
            return baseHeight + 4 + listHeight + 8;
        }
        return baseHeight;
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    property bool isInDeleteMode: noteItem.tab.deleteMode && noteItem.modelData.id === noteItem.tab.noteToDelete
    property bool isInRenameMode: noteItem.tab.renameMode && noteItem.modelData.id === noteItem.tab.noteToRename
    property bool isSelected: noteItem.tab.selectedIndex === noteItem.index
    property bool isExpanded: noteItem.index === noteItem.tab.expandedItemIndex
    property color textColor: {
        if (noteItem.isInDeleteMode) {
            return Styling.srItem("error");
        } else if (noteItem.isExpanded) {
            return Styling.srItem("pane");
        } else {
            return Colors.overSurface;
        }
    }
    property string displayText: {
        if (noteItem.isInDeleteMode) {
            return "Delete \"" + noteItem.modelData.title.substring(0, 20) + (noteItem.modelData.title.length > 20 ? '...' : '') + "\"?";
        }
        return noteItem.modelData.title || "Untitled";
    }

    function select() {
        noteItem.tab.selectedIndex = noteItem.index;
        noteItem.listView.currentIndex = noteItem.index;
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: noteItem.isExpanded ? 48 : parent.height
        hoverEnabled: true
        enabled: !noteItem.tab.deleteMode && !noteItem.tab.renameMode
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            if (!noteItem.tab.deleteMode && noteItem.tab.expandedItemIndex === -1) {
                noteItem.select();
            }
        }

        onClicked: mouse => {
            const tab = noteItem.tab;
            if (mouse.button === Qt.LeftButton && !noteItem.isInDeleteMode) {
                if (tab.deleteMode && noteItem.modelData.id !== tab.noteToDelete) {
                    tab.cancelDeleteMode();
                    return;
                }

                if (!tab.deleteMode && !noteItem.isExpanded) {
                    if (noteItem.modelData.isCreateButton || noteItem.modelData.isCreateSpecificButton) {
                        // Show create menu instead of creating directly
                        if (tab.expandedItemIndex === noteItem.index) {
                            tab.expandedItemIndex = -1;
                            tab.selectedOptionIndex = 0;
                            tab.keyboardNavigation = false;
                        } else {
                            tab.expandedItemIndex = noteItem.index;
                            noteItem.select();
                            tab.selectedOptionIndex = 0;
                            tab.keyboardNavigation = true;
                        }
                    } else {
                        tab.openNoteInEditor(noteItem.modelData.id);
                    }
                }
            } else if (mouse.button === Qt.RightButton) {
                if (tab.deleteMode) {
                    tab.cancelDeleteMode();
                    return;
                }

                if (noteItem.modelData.isCreateButton)
                    return;

                if (tab.expandedItemIndex === noteItem.index) {
                    tab.expandedItemIndex = -1;
                    tab.selectedOptionIndex = 0;
                    tab.keyboardNavigation = false;
                    noteItem.select();
                } else {
                    tab.expandedItemIndex = noteItem.index;
                    noteItem.select();
                    tab.selectedOptionIndex = 0;
                    tab.keyboardNavigation = false;
                }
            }
        }

        // Delete buttons
        NoteConfirmButtons {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            shown: noteItem.isInDeleteMode
            buttonIndex: noteItem.tab.deleteButtonIndex
            highlightVariant: "overerror"
            iconColor: Colors.overError
            highlightedIconColor: Colors.overErrorContainer
            onCancelClicked: noteItem.tab.cancelDeleteMode()
            onConfirmClicked: noteItem.tab.confirmDeleteNote()
            onButtonHovered: i => noteItem.tab.deleteButtonIndex = i
        }
    }

    // Item content
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        anchors.rightMargin: noteItem.isInRenameMode ? 84 : 8
        height: 32
        spacing: 8

        Behavior on anchors.rightMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        StyledRect {
            id: iconBackground
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            variant: {
                if (noteItem.isInDeleteMode) {
                    return "overerror";
                } else if (noteItem.isInRenameMode) {
                    return "oversecondary";
                } else if (noteItem.modelData.isCreateButton) {
                    return "primary";
                } else {
                    return "common";
                }
            }
            radius: Styling.radius(-4)

            Text {
                anchors.centerIn: parent
                text: {
                    if (noteItem.isInDeleteMode) {
                        return Icons.alert;
                    } else if (noteItem.isInRenameMode) {
                        return Icons.edit;
                    } else if (noteItem.modelData.isCreateButton) {
                        return Icons.plus;
                    } else if (noteItem.modelData.isMarkdown) {
                        return Icons.markdown;
                    } else {
                        return Icons.file;
                    }
                }
                color: iconBackground.item
                font.family: Icons.font
                font.pixelSize: 16
                textFormat: Text.RichText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Loader {
                Layout.fillWidth: true
                sourceComponent: noteItem.tab.renameMode && noteItem.modelData.id === noteItem.tab.noteToRename ? renameTextInput : normalText
            }

            Component {
                id: normalText
                Text {
                    text: noteItem.displayText
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: noteItem.isInDeleteMode ? Font.Bold : (noteItem.isSelected ? Font.Bold : Font.Normal)
                    color: noteItem.textColor
                    elide: Text.ElideRight

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }

            Component {
                id: renameTextInput
                TextField {
                    id: renameField
                    text: noteItem.tab.newNoteName
                    color: Colors.overSecondary
                    selectionColor: Colors.overSecondary
                    selectedTextColor: Colors.secondary
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    background: Item {}
                    selectByMouse: true

                    onTextChanged: {
                        noteItem.tab.newNoteName = renameField.text;
                    }

                    Component.onCompleted: {
                        Qt.callLater(() => {
                            renameField.forceActiveFocus();
                            renameField.selectAll();
                        });
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            noteItem.tab.confirmRenameNote();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            noteItem.tab.cancelRenameMode();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            noteItem.tab.renameButtonIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            noteItem.tab.renameButtonIndex = 1;
                            event.accepted = true;
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: noteItem.modelData.modified ? NotesUtils.formatTimestamp(noteItem.modelData.modified, I18n.t) : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize - 2
                color: Qt.rgba(noteItem.textColor.r, noteItem.textColor.g, noteItem.textColor.b, 0.6)
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: !noteItem.modelData.isCreateButton && text !== "" && !noteItem.isInRenameMode
            }
        }
    }

    // Rename action buttons (cancel/confirm)
    NoteConfirmButtons {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 8
        anchors.topMargin: 8
        shown: noteItem.isInRenameMode
        buttonIndex: noteItem.tab.renameButtonIndex
        highlightVariant: "oversecondary"
        iconColor: Colors.overSecondary
        highlightedIconColor: Colors.overSecondaryContainer
        onCancelClicked: noteItem.tab.cancelRenameMode()
        onConfirmClicked: noteItem.tab.confirmRenameNote()
        onButtonHovered: i => noteItem.tab.renameButtonIndex = i
    }

    // Expandable options list (matching TmuxTab styling)
    NoteItemOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        tab: noteItem.tab
        note: noteItem.modelData
        visible: noteItem.isExpanded && !noteItem.isInDeleteMode && !noteItem.isInRenameMode
        opacity: (noteItem.isExpanded && !noteItem.isInDeleteMode && !noteItem.isInRenameMode) ? 1 : 0
    }
}
