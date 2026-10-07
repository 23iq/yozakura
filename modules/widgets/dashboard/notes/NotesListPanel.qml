pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.components.kit
import qs.modules.services
import qs.config
import "notes_utils.js" as NotesUtils

// Left panel of the notes tab: search field with the list keyboard handling
// (navigate, expand options, rename, reorder, Tab to the editor) and the
// notes list (kit ListRows, the keyboard cursor is the selected row).
Item {
    id: panel

    // The NotesTab (state + actions)
    required property var tab
    required property ListModel model

    readonly property alias listView: resultsList
    readonly property alias searchField: searchInput

    function focusSearch() {
        searchInput.focusInput();
    }

    // Jump to the top without the scroll animation (list rebuilt)
    function resetScroll() {
        resultsList.enableScrollAnimation = false;
        resultsList.contentY = 0;
        Qt.callLater(() => {
            resultsList.enableScrollAnimation = true;
        });
    }

    readonly property int rowH: Space.rowHeight

    // Height of a row (with its options list when expanded)
    function rowHeight(note, expanded) {
        return NotesUtils.rowHeight(note, expanded, panel.rowH, Space.controlS, Space.xs);
    }

    // Scroll so the expanded row and its options are visible (rows above are collapsed)
    function revealExpanded() {
        const i = panel.tab.expandedItemIndex;
        if (i < 0 || i >= panel.model.count)
            return;
        const note = panel.tab.filteredNotes[i];
        const y = NotesUtils.scrollToShow(i * panel.rowH, panel.rowHeight(note, true), resultsList.contentY, resultsList.height, resultsList.contentHeight);
        if (y !== -1)
            resultsList.contentY = y;
    }

    Connections {
        target: panel.tab
        function onExpandedItemIndexChanged() {
            Qt.callLater(panel.revealExpanded);
        }
    }

    // Search input
    SearchField {
        id: searchInput
        rule: true
        width: parent.width
        anchors.top: parent.top
        text: panel.tab.searchText
        placeholderText: I18n.t("notes.search")
        prefixIcon: panel.tab.prefixIcon
        handleTabNavigation: true

        onSearchTextChanged: text => {
            panel.tab.searchText = text;
        }

        onBackspaceOnEmpty: {
            panel.tab.backspaceOnEmpty();
        }

        onAccepted: panel.tab.activateSelection()

        onShiftAccepted: {
            const tab = panel.tab;
            if (tab.selectedIndex >= 0 && tab.selectedIndex < tab.filteredNotes.length) {
                // Allow expanding both create button and regular notes
                if (tab.expandedItemIndex === tab.selectedIndex) {
                    tab.expandedItemIndex = -1;
                    tab.selectedOptionIndex = 0;
                    tab.keyboardNavigation = false;
                } else {
                    tab.expandedItemIndex = tab.selectedIndex;
                    tab.selectedOptionIndex = 0;
                    tab.keyboardNavigation = true;
                }
            }
        }

        onCtrlRPressed: {
            // Ctrl+R: Enter rename mode for selected note
            const tab = panel.tab;
            if (tab.selectedIndex >= 0 && tab.selectedIndex < tab.filteredNotes.length) {
                let note = tab.filteredNotes[tab.selectedIndex];
                if (!note.isCreateButton && !tab.deleteMode && !tab.renameMode) {
                    tab.enterRenameMode(note.id);
                }
            }
        }

        onEscapePressed: {
            const tab = panel.tab;
            if (tab.deleteMode) {
                tab.cancelDeleteMode();
            } else if (tab.renameMode) {
                tab.cancelRenameMode();
            } else if (tab.expandedItemIndex >= 0) {
                tab.expandedItemIndex = -1;
                tab.selectedOptionIndex = 0;
                tab.keyboardNavigation = false;
            } else {
                Visibilities.setActiveModule("");
            }
        }

        onDownPressed: {
            const tab = panel.tab;
            if (tab.deleteMode || tab.renameMode)
                return;
            if (tab.expandedItemIndex >= 0) {
                // Max options: 2 for create button, 3 for notes
                var isCreateBtn = tab.expandedItemIndex < tab.filteredNotes.length && tab.filteredNotes[tab.expandedItemIndex].isCreateButton;
                var maxIndex = isCreateBtn ? 1 : 2;
                if (tab.selectedOptionIndex < maxIndex) {
                    tab.selectedOptionIndex++;
                    tab.keyboardNavigation = true;
                }
            } else if (resultsList.count > 0) {
                if (tab.selectedIndex === -1) {
                    tab.selectedIndex = 0;
                    resultsList.currentIndex = 0;
                } else if (tab.selectedIndex < resultsList.count - 1) {
                    tab.selectedIndex++;
                    resultsList.currentIndex = tab.selectedIndex;
                }
            }
        }

        onUpPressed: {
            const tab = panel.tab;
            if (tab.deleteMode || tab.renameMode)
                return;
            if (tab.expandedItemIndex >= 0) {
                if (tab.selectedOptionIndex > 0) {
                    tab.selectedOptionIndex--;
                    tab.keyboardNavigation = true;
                }
            } else if (tab.selectedIndex > 0) {
                tab.selectedIndex--;
                resultsList.currentIndex = tab.selectedIndex;
            } else if (tab.selectedIndex === 0 && tab.searchText.length === 0) {
                tab.selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        onCtrlUpPressed: {
            panel.tab.moveNoteUp();
        }

        onCtrlDownPressed: {
            panel.tab.moveNoteDown();
        }

        onTabPressed: {
            // Focus editor when pressing Tab
            panel.tab.focusEditor();
        }
    }

    SectionLabel {
        id: section
        anchors.top: searchInput.bottom
        anchors.topMargin: Space.l
        x: Space.s
        width: parent.width - Space.s * 2
        text: I18n.t("launcher.provider.notes")
    }

    // Results list
    ListView {
        id: resultsList
        width: parent.width
        anchors.top: section.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Space.s
        clip: true
        model: panel.model
        currentIndex: panel.tab.selectedIndex
        spacing: 0
        interactive: !panel.tab.deleteMode && !panel.tab.renameMode && panel.tab.expandedItemIndex === -1

        property bool enableScrollAnimation: true

        Behavior on contentY {
            enabled: resultsList.enableScrollAnimation && Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        onCurrentIndexChanged: {
            if (resultsList.currentIndex >= 0 && resultsList.currentIndex < resultsList.count) {
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain);
            }
        }

        ScrollBar.vertical: ScrollBar {
            active: resultsList.moving
        }

        delegate: NoteListItem {
            tab: panel.tab
            panel: panel
        }
    }
}
