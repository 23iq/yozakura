import QtQuick
import qs.modules.theme
import qs.config
import "../settings/Ui.js" as Ui

// Wizard button. `kind`: "filled" (primary action), "tonal", "ghost".
// Sized from the font so it scales with any theme font size.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string trailingIcon: ""
    property string kind: "tonal"
    signal clicked

    readonly property int pad: Math.round(Styling.fontSize(0) * 1.3)
    implicitWidth: row.implicitWidth + pad * 2
    implicitHeight: Math.round(Styling.fontSize(0) * 2.7)
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.4

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    readonly property color fg: kind === "filled" ? Colors.overPrimary : (kind === "ghost" ? Colors.overBackground : Colors.primary)

    Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, Styling.radius(4))
        color: {
            if (root.kind === "filled")
                return area.containsMouse ? Ui.mix(Colors.primary, Colors.overPrimary, 0.12) : Colors.primary;
            if (root.kind === "ghost")
                return area.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : "transparent";
            return area.containsMouse ? Ui.alpha(Colors.primary, 0.24) : Ui.alpha(Colors.primary, 0.14);
        }
        border.width: root.activeFocus ? 2 : 0
        border.color: root.kind === "filled" ? Colors.overPrimary : Colors.primary
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(Styling.fontSize(0) * 0.5)

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: root.fg
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: root.fg
        }
        Text {
            visible: root.trailingIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.trailingIcon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: root.fg
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
