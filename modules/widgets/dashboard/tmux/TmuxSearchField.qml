import QtQuick
import qs.modules.components.kit
import qs.modules.services

// Search field of the tmux tab. Owns the keyboard flow while typing:
// arrows/page/home/end move the selection in `list`, Shift+Enter toggles
// the options menu (then arrows pick an option), Enter runs the selected
// row or option, Ctrl+R renames, Escape closes the menu or the dashboard.
SearchField {
    id: field

    required property var tab
    required property ListView list

    rule: true

    onSearchTextChanged: text => {
        field.tab.searchText = text;
    }

    onBackspaceOnEmpty: {
        field.tab.backspaceOnEmpty();
    }

    onAccepted: {
        if (field.tab.deleteMode) {
            field.tab.cancelDeleteMode();
        } else if (field.tab.expandedItemIndex >= 0) {
            // Execute selected option when menu is expanded
            let session = field.tab.filteredSessions[field.tab.expandedItemIndex];
            if (session && !session.isCreateButton && !session.isCreateSpecificButton) {
                // Build options array (Open, Rename, Quit)
                let options = [function () {
                        field.tab.attachToSession(session.name);
                    }, function () {
                        field.tab.enterRenameMode(session.name);
                        field.tab.expandedItemIndex = -1;
                    }, function () {
                        field.tab.enterDeleteMode(session.name);
                        field.tab.expandedItemIndex = -1;
                    }];

                if (field.tab.selectedOptionIndex >= 0 && field.tab.selectedOptionIndex < options.length) {
                    options[field.tab.selectedOptionIndex]();
                }
            }
        } else {
            if (field.tab.selectedIndex >= 0 && field.tab.selectedIndex < field.list.count) {
                let selectedSession = field.tab.filteredSessions[field.tab.selectedIndex];
                if (selectedSession) {
                    if (selectedSession.isCreateSpecificButton) {
                        field.tab.createTmuxSession(selectedSession.sessionNameToCreate);
                    } else if (selectedSession.isCreateButton) {
                        field.tab.createTmuxSession();
                    } else {
                        field.tab.attachToSession(selectedSession.name);
                    }
                }
            } else {
                console.log("DEBUG: No action taken - selectedIndex:", field.tab.selectedIndex, "count:", field.list.count);
            }
        }
    }

    onShiftAccepted: {
        if (!field.tab.deleteMode && !field.tab.renameMode) {
            if (field.tab.selectedIndex >= 0 && field.tab.selectedIndex < field.list.count) {
                let selectedSession = field.tab.filteredSessions[field.tab.selectedIndex];
                if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                    // Toggle expanded state
                    if (field.tab.expandedItemIndex === field.tab.selectedIndex) {
                        field.tab.expandedItemIndex = -1;
                        field.tab.selectedOptionIndex = 0;
                        field.tab.keyboardNavigation = false;
                    } else {
                        field.tab.expandedItemIndex = field.tab.selectedIndex;
                        field.tab.selectedOptionIndex = 0;
                        field.tab.keyboardNavigation = true;
                    }
                }
            }
        }
    }

    onCtrlRPressed: {
        if (!field.tab.deleteMode && !field.tab.renameMode && field.tab.selectedIndex >= 0 && field.tab.selectedIndex < field.list.count) {
            let selectedSession = field.tab.filteredSessions[field.tab.selectedIndex];
            if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                field.tab.enterRenameMode(selectedSession.name);
            }
        }
    }

    onEscapePressed: {
        if (field.tab.expandedItemIndex >= 0) {
            field.tab.expandedItemIndex = -1;
            field.tab.selectedOptionIndex = 0;
            field.tab.keyboardNavigation = false;
        } else if (!field.tab.deleteMode && !field.tab.renameMode) {
            Visibilities.setActiveModule("");
        }
    }

    onDownPressed: {
        if (field.tab.expandedItemIndex >= 0) {
            // Navigate options when menu is expanded - always 3 options
            if (field.tab.selectedOptionIndex < 2) {
                field.tab.selectedOptionIndex++;
                field.tab.keyboardNavigation = true;
            }
        } else if (!field.tab.deleteMode && !field.tab.renameMode && field.list.count > 0) {
            if (field.tab.selectedIndex === -1) {
                field.tab.selectedIndex = 0;
                field.list.currentIndex = 0;
            } else if (field.tab.selectedIndex < field.list.count - 1) {
                field.tab.selectedIndex++;
                field.list.currentIndex = field.tab.selectedIndex;
            }
        }
    }

    onUpPressed: {
        if (field.tab.expandedItemIndex >= 0) {
            // Navigate options when menu is expanded
            if (field.tab.selectedOptionIndex > 0) {
                field.tab.selectedOptionIndex--;
                field.tab.keyboardNavigation = true;
            }
        } else if (!field.tab.deleteMode && !field.tab.renameMode) {
            if (field.tab.selectedIndex > 0) {
                field.tab.selectedIndex--;
                field.list.currentIndex = field.tab.selectedIndex;
            } else if (field.tab.selectedIndex === 0 && field.tab.searchText.length === 0) {
                field.tab.selectedIndex = -1;
                field.list.currentIndex = -1;
            }
        }
    }

    onPageDownPressed: {
        if (!field.tab.deleteMode && !field.tab.renameMode && field.list.count > 0) {
            let visibleItems = Math.floor(field.list.height / 28);
            let newIndex = Math.min(field.tab.selectedIndex + visibleItems, field.list.count - 1);
            if (field.tab.selectedIndex === -1) {
                newIndex = Math.min(visibleItems - 1, field.list.count - 1);
            }
            field.tab.selectedIndex = newIndex;
            field.list.currentIndex = field.tab.selectedIndex;
        }
    }

    onPageUpPressed: {
        if (!field.tab.deleteMode && !field.tab.renameMode && field.list.count > 0) {
            let visibleItems = Math.floor(field.list.height / 28);
            let newIndex = Math.max(field.tab.selectedIndex - visibleItems, 0);
            if (field.tab.selectedIndex === -1) {
                newIndex = Math.max(field.list.count - visibleItems, 0);
            }
            field.tab.selectedIndex = newIndex;
            field.list.currentIndex = field.tab.selectedIndex;
        }
    }

    onHomePressed: {
        if (!field.tab.deleteMode && !field.tab.renameMode && field.list.count > 0) {
            field.tab.selectedIndex = 0;
            field.list.currentIndex = 0;
        }
    }

    onEndPressed: {
        if (!field.tab.deleteMode && !field.tab.renameMode && field.list.count > 0) {
            field.tab.selectedIndex = field.list.count - 1;
            field.list.currentIndex = field.tab.selectedIndex;
        }
    }
}
