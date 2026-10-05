pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../../Ui.js" as Ui
import "../../../specials/Specials.js" as Specials

// Icon choice for a special workspace: one chip per Specials.ICONS glyph,
// drawn in the special's accent (a palette role).
Flow {
    id: root

    property string value: "stack"
    property string accent: "primary"
    signal picked(string icon)

    readonly property color tint: Colors[root.accent] ?? Colors.primary

    spacing: 6

    Repeater {
        model: Specials.ICONS
        delegate: Rectangle {
            id: chip
            required property string modelData
            readonly property bool selected: root.value === modelData
            objectName: "glyph:" + modelData
            width: 34
            height: 34
            radius: Math.min(Styling.radius(-2), 12)
            color: selected ? Ui.alpha(root.tint, 0.22) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : "transparent")
            border.width: selected ? 1 : 0
            border.color: root.tint
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData
            Accessible.checked: selected

            Text {
                anchors.centerIn: parent
                text: Icons[chip.modelData] || ""
                font.family: Icons.font
                font.pixelSize: 17
                color: chip.selected ? root.tint : Colors.overSurfaceVariant
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(chip.modelData)
            }
        }
    }
}
