import QtQuick
import qs.modules.services
import qs.modules.components.kit

// The history section label with its "Clear" action: the first press turns
// it into "Clear all?", the second clears. Reachable with Tab from the
// search field (Enter activates, Escape / Shift+Tab go back).
SectionLabel {
    id: clearButton

    required property ClipboardTabBase tab

    function activate() {
        if (clearButton.tab.clearButtonConfirmState) {
            clearButton.tab.clearClipboardHistory();
        } else {
            clearButton.tab.clearButtonConfirmState = true;
        }
    }

    function leave() {
        clearButton.tab.resetClearButton();
        clearButton.tab.clearButtonFocused = false;
        clearButton.tab.focusSearchInput();
    }

    text: I18n.t("clipboard.history")
    action: clearButton.tab.clearButtonConfirmState ? I18n.t("clipboard.clear_all_confirm") : I18n.t("common.clear")
    actionHighlighted: clearButton.tab.clearButtonFocused || clearButton.tab.clearButtonConfirmState
    visible: ClipboardService.items.length > 0
    focus: clearButton.tab.clearButtonFocused
    activeFocusOnTab: true
    onTriggered: clearButton.activate()

    onActiveFocusChanged: {
        if (activeFocus) {
            clearButton.tab.clearButtonFocused = true;
        } else {
            clearButton.tab.clearButtonFocused = false;
            clearButton.tab.resetClearButton();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            clearButton.activate();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            clearButton.leave();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            clearButton.leave();
            event.accepted = true;
        }
    }
}
