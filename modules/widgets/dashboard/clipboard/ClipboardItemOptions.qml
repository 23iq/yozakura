pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ClipboardView.js" as ClipboardView

// Options of an expanded row as compact kit ListRows: Copy, Open (files,
// images, URLs), Pin, Alias, Delete. Keyboard cursor: tab.selectedOptionIndex.
Column {
    id: options

    required property ClipboardTabBase tab
    required property var entry
    property bool shown: false

    readonly property var model: {
        const tab = options.tab;
        const entry = options.entry;
        var list = [
            {
                text: I18n.t("common.copy"),
                icon: Icons.copy,
                action: function () {
                    tab.copyToClipboard(entry.id);
                    Visibilities.setActiveModule("");
                }
            }
        ];
        if (ClipboardView.canOpen(entry)) {
            list.push({
                text: I18n.t("common.open"),
                icon: Icons.popOpen,
                action: function () {
                    tab.openItem(entry.id);
                }
            });
        }
        list.push({
            text: entry.pinned ? I18n.t("clipboard.unpin") : I18n.t("clipboard.pin"),
            icon: entry.pinned ? Icons.unpin : Icons.pin,
            action: function () {
                tab.pendingItemIdToSelect = entry.id;
                ClipboardService.togglePin(entry.id);
                tab.expandedItemIndex = -1;
            }
        }, {
            text: I18n.t("clipboard.alias"),
            icon: Icons.edit,
            action: function () {
                tab.enterAliasMode(entry.id);
                tab.expandedItemIndex = -1;
            }
        }, {
            text: I18n.t("common.delete"),
            icon: Icons.trash,
            danger: true,
            action: function () {
                tab.enterDeleteMode(entry.id);
                tab.expandedItemIndex = -1;
            }
        });
        return list;
    }

    visible: options.shown
    height: ClipboardView.optionsListHeight(options.entry)

    Repeater {
        model: options.shown ? options.model : []

        ListRow {
            id: option
            required property var modelData
            required property int index

            width: options.width
            height: ClipboardView.OPTION_HEIGHT
            title: option.modelData.text
            highlighted: options.tab.selectedOptionIndex === option.index
            onClicked: option.modelData.action()
            onHoveredChanged: {
                if (option.hovered && !option.highlighted) {
                    options.tab.selectedOptionIndex = option.index;
                    options.tab.keyboardNavigation = false;
                }
            }

            leading: Component {
                Text {
                    width: Metrics.iconSize
                    horizontalAlignment: Text.AlignHCenter
                    text: option.modelData.icon
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: option.modelData.danger ? Colors.error : Type.secondary
                }
            }
        }
    }
}
