import QtQuick
import qs.modules.components
import qs.modules.services
import "ClipboardView.js" as ClipboardView

// Search field of the clipboard tab (plus the clear-history button). The
// field owns the keyboard: Enter copies (or runs the open option), Shift+Enter
// toggles the options menu, Ctrl+R alias, Ctrl+P pin, Ctrl+Up/Down reorder.
Row {
    id: bar

    required property ClipboardTabBase tab

    function focusInput() {
        searchInput.focusInput();
    }

    spacing: 8

    SearchInput {
        id: searchInput
        width: parent.width - clearButton.width - parent.spacing
        height: parent.height
        text: bar.tab.searchText
        placeholderText: I18n.t("clipboard.search")
        prefixIcon: bar.tab.prefixIcon

        onSearchTextChanged: text => {
            bar.tab.searchText = text;
        }

        onBackspaceOnEmpty: {
            bar.tab.backspaceOnEmpty();
        }

        onAccepted: {
            const tab = bar.tab;
            if (tab.deleteMode) {
                tab.cancelDeleteMode();
            } else if (tab.expandedItemIndex >= 0) {
                // Execute selected option when menu is expanded
                let item = tab.allItems[tab.expandedItemIndex];
                if (item) {
                    let options = [function () {
                            tab.copyToClipboard(item.id);
                            Visibilities.setActiveModule("");
                        }];
                    if (ClipboardView.canOpen(item)) {
                        options.push(function () {
                            tab.openItem(item.id);
                        });
                    }
                    options.push(function () {
                        tab.pendingItemIdToSelect = item.id;
                        ClipboardService.togglePin(item.id);
                        tab.expandedItemIndex = -1;
                    }, function () {
                        tab.enterAliasMode(item.id);
                        tab.expandedItemIndex = -1;
                    }, function () {
                        tab.enterDeleteMode(item.id);
                        tab.expandedItemIndex = -1;
                    });
                    if (tab.selectedOptionIndex >= 0 && tab.selectedOptionIndex < options.length) {
                        options[tab.selectedOptionIndex]();
                    }
                }
            } else if (tab.selectedIndex >= 0 && tab.selectedIndex < tab.allItems.length) {
                let selectedItem = tab.allItems[tab.selectedIndex];
                if (selectedItem && !tab.deleteMode) {
                    tab.copyToClipboard(selectedItem.id);
                    Visibilities.setActiveModule("");
                }
            }
        }

        onShiftAccepted: {
            const tab = bar.tab;
            if (!tab.deleteMode && !tab.aliasMode && tab.selectedIndex >= 0 && tab.selectedIndex < tab.allItems.length) {
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
            const item = bar.tab.actionableItem();
            if (item && !item.isCreateButton)
                bar.tab.enterAliasMode(item.id);
        }

        onCtrlPPressed: {
            const item = bar.tab.actionableItem();
            if (item) {
                bar.tab.pendingItemIdToSelect = item.id;
                ClipboardService.togglePin(item.id);
            }
        }

        onCtrlUpPressed: {
            const item = bar.tab.actionableItem();
            if (item) {
                bar.tab.pendingItemIdToSelect = item.id;
                ClipboardService.moveItemUp(item.id);
            }
        }

        onCtrlDownPressed: {
            const item = bar.tab.actionableItem();
            if (item) {
                bar.tab.pendingItemIdToSelect = item.id;
                ClipboardService.moveItemDown(item.id);
            }
        }

        onEscapePressed: {
            if (bar.tab.expandedItemIndex >= 0) {
                bar.tab.collapseOptions();
            } else if (!bar.tab.deleteMode) {
                Visibilities.setActiveModule("");
            }
        }

        onDownPressed: {
            const tab = bar.tab;
            if (tab.expandedItemIndex >= 0) {
                // Navigate the options of the expanded row
                let item = tab.allItems[tab.expandedItemIndex];
                if (item && tab.selectedOptionIndex < ClipboardView.optionsCount(item) - 1) {
                    tab.selectedOptionIndex++;
                    tab.keyboardNavigation = true;
                }
            } else {
                tab.onDownPressed();
            }
        }

        onUpPressed: {
            const tab = bar.tab;
            if (tab.expandedItemIndex >= 0) {
                if (tab.selectedOptionIndex > 0) {
                    tab.selectedOptionIndex--;
                    tab.keyboardNavigation = true;
                }
            } else {
                tab.onUpPressed();
            }
        }
    }

    ClipboardClearButton {
        id: clearButton
        tab: bar.tab
        radius: searchInput.radius
    }
}
