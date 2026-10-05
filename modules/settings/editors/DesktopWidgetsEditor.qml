pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.desktop.widgets
import qs.modules.settings.editors.desktopwidgets
import "../../desktop/widgets/WidgetRegistry.js" as Registry
import "../Ui.js" as Ui

// Desktop widgets: add one of each registered type, arrange them on the
// desktop (edit desktop mode), see where they sit per screen, tune each
// widget's options or remove it. Writes desktop.widgets through
// SettingsStore (staged with the other shell settings).
ColumnLayout {
    id: root

    property var entry
    readonly property var list: DesktopWidgets.widgets
    readonly property var screens: Quickshell.screens || []
    readonly property var screenNames: screens.map(s => s.name)
    readonly property var manager: GlobalStates.wallpaperManager

    function screenOf(name) {
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i];
        }
        return screens[0] ?? null;
    }
    function sizeOf(name) {
        const s = screenOf(name);
        return s ? {
            w: s.width,
            h: s.height
        } : {
            w: 2560,
            h: 1440
        };
    }
    function wallpaperFor(name) {
        const m = manager;
        if (!m)
            return "";
        const p = (m.perScreenWallpapers ?? {})[name] || m.currentWallpaper || "";
        return p ? "file://" + m.getDisplaySource(p) : "";
    }
    function commit(next) {
        SettingsStore.set("desktop.widgets", next);
    }
    function add(type) {
        const name = screenNames[0] ?? "";
        const size = sizeOf(name);
        commit(DesktopWidgets.withAdded(DesktopWidgets.copy(), type, name, size.w, size.h, null));
    }

    spacing: 12

    onListChanged: ids.sync(list.map(w => w.id))
    Component.onCompleted: ids.sync(list.map(w => w.id))

    WidgetIdModel {
        id: ids
    }

    // Add + arrange
    Flow {
        Layout.fillWidth: true
        spacing: 8

        PillButton {
            objectName: "widgetsEditMode"
            kind: DesktopWidgets.editMode ? "filled" : "tonal"
            icon: DesktopWidgets.editMode ? "accept" : "arrowsOutCardinal"
            text: DesktopWidgets.editMode ? I18n.t("desktop.widgets.done") : I18n.t("desktop.widgets.edit")
            onClicked: DesktopWidgets.toggleEditMode()
        }

        Repeater {
            model: Registry.types
            PillButton {
                required property var modelData
                objectName: "addWidget:" + modelData.id
                kind: "ghost"
                icon: modelData.icon
                text: I18n.t("desktop.widgets.add") + " " + I18n.t(modelData.labelKey)
                onClicked: root.add(modelData.id)
            }
        }
    }

    // Where they are, per screen.
    Flow {
        Layout.fillWidth: true
        spacing: 12
        visible: root.list.length > 0

        Repeater {
            model: root.screenNames.length > 0 ? root.screenNames : [""]
            WidgetLayoutMap {
                required property string modelData
                width: root.screenNames.length > 1 ? Math.min(260, (root.width - 12) / 2) : Math.min(320, root.width)
                height: width * 9 / 16 + 18
                screenName: modelData
                screenW: root.sizeOf(modelData).w
                screenH: root.sizeOf(modelData).h
                widgets: root.screenNames.length > 0 ? DesktopWidgets.forScreen(modelData) : root.list
                wallpaper: root.wallpaperFor(modelData)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.list.length === 0
        text: I18n.t("desktop.widgets.empty")
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
    }

    Repeater {
        model: ids
        WidgetCard {
            id: card
            required property string wid
            readonly property var found: root.list.find(w => w.id === card.wid) ?? null
            Layout.fillWidth: true
            visible: found !== null
            widget: found
            screenW: root.sizeOf(found?.monitor ?? "").w
            screenH: root.sizeOf(found?.monitor ?? "").h
            screenNames: root.screenNames
            onOptionSet: (key, value) => root.commit(DesktopWidgets.withOption(DesktopWidgets.copy(), card.wid, key, value))
            onMonitorSet: name => root.commit(DesktopWidgets.withUpdated(DesktopWidgets.copy(), card.wid, {
                    monitor: name
                }))
            onRemoveRequested: root.commit(DesktopWidgets.withRemoved(DesktopWidgets.copy(), card.wid))
        }
    }
}
