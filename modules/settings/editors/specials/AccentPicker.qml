pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import "../../Ui.js" as Ui
import "../../../specials/Specials.js" as Specials

// Accent of a special workspace: palette roles only (Specials.ACCENTS),
// drawn in the live palette so every wallpaper and preset works.
Row {
    id: root

    property string value: "primary"
    signal picked(string role)

    spacing: 8

    Repeater {
        model: Specials.ACCENTS
        delegate: Rectangle {
            id: swatch
            required property string modelData
            readonly property bool selected: root.value === modelData
            objectName: "accent:" + modelData
            width: 26
            height: 26
            radius: 13
            color: "transparent"
            border.width: selected ? 2 : 1
            border.color: selected ? Colors.overBackground : Ui.alpha(Colors.outlineVariant, 0.9)
            Accessible.role: Accessible.RadioButton
            Accessible.name: I18n.t("specials.accent." + modelData)
            Accessible.checked: selected

            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: Colors[swatch.modelData] ?? Colors.outline
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(swatch.modelData)
            }
        }
    }
}
