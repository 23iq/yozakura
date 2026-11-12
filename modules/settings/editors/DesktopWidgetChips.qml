pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../desktop/widgets/WidgetRegistry.js" as Registry
import "../stages/DesktopPlace.js" as DesktopPlace
import "../SchemaUtil.js" as SchemaUtil

// The desktop widgets as chips, one per type (WidgetRegistry), lit while
// one is on the desktop: a click puts one in the first free spot of the
// first screen, or takes them all away (desktop.widgets, one undo step).
// The stage shows it at once. Arranging and each widget's options are in
// the full editor ("More").
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var list: SchemaUtil.plain(SettingsStore.get("desktop.widgets")) || []
    readonly property var screen: {
        const s = (Quickshell.screens || [])[0];
        return s ? {
            "name": s.name,
            "w": s.width,
            "h": s.height
        } : {
            "name": "",
            "w": 2560,
            "h": 1440
        };
    }

    implicitHeight: Math.max(root.fillHeight, flow.implicitHeight + arrange.height + Space.m)

    // arranging and each widget's options: the full editor in "More"
    Chip {
        id: arrange
        objectName: "desktopWidgetsArrange"
        anchors.bottom: parent.bottom
        quiet: true
        dense: true
        icon: Icons.arrowsOutCardinal
        trailingIcon: Icons.caretRight
        text: I18n.t("desktop.widgets.edit")
        onClicked: SettingsStore.navigate("desktop", "arrange", "desktop.widgets")
    }

    Flow {
        id: flow
        width: root.width
        spacing: Space.s
        Repeater {
            model: Registry.types
            delegate: Chip {
                id: chip
                required property var modelData
                readonly property int count: DesktopPlace.countOf(Registry.normalizeList(root.list), modelData.id)
                objectName: "desktopWidget:" + modelData.id
                active: chip.count > 0
                icon: Icons[modelData.icon] ?? ""
                text: I18n.t(modelData.labelKey)
                Accessible.checked: chip.active
                onClicked: SettingsStore.set("desktop.widgets", DesktopPlace.toggled(root.list, chip.modelData.id, root.screen, Number(SettingsStore.get("desktop.widgetGrid") ?? 24), []))
            }
        }
    }
}
