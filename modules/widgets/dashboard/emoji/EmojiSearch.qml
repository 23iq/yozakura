import QtQuick
import qs.modules.components.kit
import qs.modules.services

// The emoji tab's search field (kit SearchField, the tab's mode glyph) and
// its keys: Enter copies, Shift+Enter opens the tone options, arrows move.
SearchField {
    id: field

    required property var tab

    rule: true
    text: field.tab.searchText
    placeholderText: I18n.t("emoji.search")
    prefixIcon: field.tab.prefixIcon

    onSearchTextChanged: text => field.tab.searchText = text
    onBackspaceOnEmpty: field.tab.backspaceOnEmpty()
    onAccepted: field.tab.activate()
    onShiftAccepted: {
        const t = field.tab;
        if (t.selectedIndex < 0 || t.selectedIndex >= t.model.count)
            return;
        const item = t.model.get(t.selectedIndex);
        if (!item.isRecentContainer && item.emojiData.skin_tone_support)
            t.toggleOptions(t.selectedIndex, true);
    }
    onEscapePressed: {
        if (field.tab.expandedItemIndex >= 0)
            field.tab.collapseOptions();
        else if (field.tab.searchText.length === 0)
            Visibilities.setActiveModule("");
        else
            field.tab.clearSearch();
    }
    onDownPressed: field.tab.onDownPressed()
    onUpPressed: field.tab.onUpPressed()
    onLeftPressed: field.tab.onLeftPressed()
    onRightPressed: field.tab.onRightPressed()
}
