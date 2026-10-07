pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.config

// Left panel of the notes tab: search field with the list keyboard handling
// (navigate, expand options, rename, reorder, Tab to the editor) and the
// notes list with its animated selection highlight.
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

    // Height of a row: 48, or 48 + its options list when expanded
    function rowHeight(i) {
        const tab = panel.tab;
        if (i === tab.expandedItemIndex && !tab.deleteMode && !tab.renameMode) {
            var isCreateBtn = i >= 0 && i < tab.filteredNotes.length && tab.filteredNotes[i].isCreateButton;
            var optionCount = isCreateBtn ? 2 : 3;
            var listHeight = 36 * optionCount;
            return 48 + 4 + listHeight + 8;
        }
        return 48;
    }

    // Search input
    SearchField {
        id: searchInput
        rule: true
        width: parent.width
        height: 48
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

    // Results list
    ListView {
        id: resultsList
        width: parent.width
        anchors.top: searchInput.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
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
                easing.type: Motion.morph.easing
            }
        }

        onCurrentIndexChanged: {
            if (resultsList.currentIndex >= 0 && resultsList.currentIndex < resultsList.count) {
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain);
            }
        }

        ScrollBar.vertical: ScrollBar {
            active: true
        }

        highlight: Item {
            id: highlightItem
            width: resultsList.width
            height: panel.rowHeight(resultsList.currentIndex)

            y: {
                var yPos = 0;
                for (var i = 0; i < resultsList.currentIndex && i < panel.model.count; i++) {
                    yPos += panel.rowHeight(i);
                }
                return yPos;
            }

            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.morph.easing
                }
            }

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Motion.morph.easing
                }
            }

            onHeightChanged: {
                if (panel.tab.expandedItemIndex >= 0 && highlightItem.height > 48) {
                    Qt.callLater(() => {
                        panel.tab.adjustScrollForExpandedItem(panel.tab.expandedItemIndex);
                    });
                }
            }

            StyledRect {
                anchors.fill: parent
                variant: {
                    const tab = panel.tab;
                    if (tab.deleteMode) {
                        return "error";
                    } else if (tab.renameMode) {
                        return "secondary";
                    } else if (tab.expandedItemIndex >= 0 && tab.selectedIndex === tab.expandedItemIndex) {
                        return "pane";
                    } else {
                        return "primary";
                    }
                }
                radius: Styling.radius(4)
                backgroundOpacity: variant === "primary" ? Look.activeTint : -1
                visible: panel.tab.selectedIndex >= 0

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }

        highlightFollowsCurrentItem: false

        delegate: NoteListItem {
            tab: panel.tab
            listView: resultsList
        }
    }
}
