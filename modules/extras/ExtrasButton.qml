import QtQuick
import qs.modules.theme
import qs.config
import "ExtrasUi.js" as Ui

// Rounded text button of the extras components. `kind`: "tonal" (default),
// "filled", "ghost", "solid". Same look as the settings PillButton.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string kind: "tonal"
    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.45

    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    readonly property color fg: kind === "filled" ? Colors.overPrimary : (kind === "ghost" || kind === "solid" ? Colors.overBackground : Colors.primary)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (root.kind === "filled")
                return area.containsMouse ? Ui.mix(Colors.primary, Colors.overPrimary, 0.12) : Colors.primary;
            if (root.kind === "solid")
                return area.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh;
            if (root.kind === "ghost")
                return area.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : Ui.alpha(Colors.overBackground, 0.06);
            return area.containsMouse ? Ui.alpha(Colors.primary, 0.24) : Ui.alpha(Colors.primary, 0.14);
        }
        border.width: root.activeFocus ? 2 : 0
        border.color: Colors.primary
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.morph.duration
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[root.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 14
            color: root.fg
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
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
