pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../../desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles

// Depth clock style picker: every registered style (ClockStyleRegistry.js)
// rendered live on the current wallpaper with its subject cutout and the
// chosen ink.
Item {
    id: root

    property var entry
    readonly property string current: ClockStyles.get(SettingsStore.get("desktop.depthClockStyle")).id
    readonly property string ink: SettingsStore.get("desktop.depthClockInk") ?? "auto"
    readonly property int columns: width < 520 ? 1 : 2

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: ClockStyles.styles

            delegate: ChoiceCard {
                id: card
                required property var modelData
                objectName: "clockStyle:" + modelData.id
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round((width - 16) * 9 / 16)
                selected: root.current === modelData.id
                title: I18n.t(modelData.labelKey)
                icon: modelData.icon
                onClicked: SettingsStore.set("desktop.depthClockStyle", modelData.id)

                ClockStyleScene {
                    anchors.fill: parent
                    styleId: card.modelData.id
                    inkRole: root.ink
                }
            }
        }
    }
}
