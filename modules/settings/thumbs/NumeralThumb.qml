pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals

// Card picture of a numeral system (workspaces.numeralStyle): workspaces
// 1 to 4 on a piece of your bar written in system `value`, the second one
// active, in the system's own font where it has one.
MiniScreen {
    id: root

    property var entry
    property var value: WorkspaceNumerals.DEFAULT_ID
    readonly property var system: WorkspaceNumerals.get(String(root.value))
    readonly property real cell: Math.round(root.height * 0.4)

    StyledRect {
        anchors.centerIn: parent
        width: row.width + Space.l
        height: root.cell + Space.s
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: Math.min(Styling.radius(0), height / 2)

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Space.xs
            Repeater {
                model: 4
                delegate: Mark {
                    id: ws
                    required property int index
                    readonly property bool current: index === 1
                    width: Math.max(root.cell, label.implicitWidth + Space.s)
                    height: root.cell
                    color: ws.current ? Colors.primary : "transparent"
                    KitText {
                        id: label
                        anchors.centerIn: parent
                        text: WorkspaceNumerals.format(String(root.value), ws.index + 1)
                        font.family: root.system && root.system.font && root.system.font.prefer ? root.system.font.prefer[0] : Type.bodyFont
                        font.pixelSize: Math.round(root.cell * 0.5)
                        font.weight: Font.Black
                        color: ws.current ? Colors.overPrimary : Colors.overBackground
                    }
                }
            }
        }
    }
}
