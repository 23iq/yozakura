pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles

// Card picture of the active workspace indicator (workspaces.indicatorStyle):
// four workspaces on a piece of your bar in your numerals, the real
// indicator component (modules/bar/workspaces/indicators) on the second.
// Strip styles (the branch) draw the whole strip themselves.
MiniScreen {
    id: root

    property var entry
    property var value: IndicatorStyles.DEFAULT_ID
    readonly property var style: IndicatorStyles.get(String(root.value))
    readonly property real cell: Math.round(root.height * 0.4)
    readonly property string numerals: SettingsStore.get("workspaces.numeralStyle") || WorkspaceNumerals.DEFAULT_ID

    StyledRect {
        id: bar
        anchors.centerIn: parent
        width: root.cell * 4 + Space.l
        height: root.cell + Space.s
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: Math.min(Styling.radius(0), height / 2)

        // A fake ActiveIndicator for the style component.
        QtObject {
            id: fake
            readonly property bool vertical: false
            readonly property real width: root.style.strip ? root.cell * 4 : root.cell
            readonly property real height: root.cell
            readonly property real slotSize: root.cell
            readonly property real padding: 0
            readonly property bool occupied: true
            readonly property real baseRadius: Styling.radius(0)
            readonly property int workspaceId: 2
        }

        Row {
            id: slots
            anchors.centerIn: parent
            Repeater {
                model: 4
                delegate: Item {
                    id: ws
                    required property int index
                    width: root.cell
                    height: root.cell

                    Loader {
                        active: ws.index === 1 && !root.style.strip
                        source: active ? Qt.resolvedUrl("../../bar/workspaces/indicators/" + root.style.component) : ""
                        onLoaded: item.indicator = fake
                    }
                    KitText {
                        anchors.centerIn: parent
                        text: WorkspaceNumerals.format(root.numerals, ws.index + 1)
                        font.pixelSize: Math.round(root.cell * 0.46)
                        font.weight: Font.DemiBold
                        color: ws.index === 1 ? (root.style.filled ? Styling.srItem("primary") : Colors.primary) : Colors.overBackground
                    }
                }
            }
        }
        Loader {
            x: slots.x
            y: slots.y
            active: !!root.style.strip
            source: active ? Qt.resolvedUrl("../../bar/workspaces/indicators/" + root.style.component) : ""
            onLoaded: item.indicator = fake
        }
    }
}
