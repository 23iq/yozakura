pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.previews
import "../Ui.js" as Ui

// Card picture of where notifications show (notifications.presentation):
// grown from the island (notch), a toast in the corner, or paper strips
// hanging from the top edge (strips). Auto draws the island and the corner
// faintly with a wand: the bar's style decides.
ScreenBackdrop {
    id: root

    property var entry
    property var value: "auto"
    readonly property bool auto: value === "auto"
    readonly property real unit: Math.min(width, height) / 10

    // the island, with a toast grown from it
    Rectangle {
        visible: root.value === "notch" || root.auto
        opacity: root.auto ? 0.45 : 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.width * 0.46
        height: root.unit * 3.4
        radius: root.unit * 1.2
        color: Colors.surfaceContainerHighest

        Rectangle {
            x: root.unit * 0.7
            anchors.verticalCenter: parent.verticalCenter
            width: root.unit * 1.6
            height: width
            radius: width / 2
            color: Colors.primary
        }
        Column {
            x: root.unit * 2.8
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.unit * 0.4
            Rectangle {
                width: root.width * 0.24
                height: Math.max(2, root.unit * 0.45)
                radius: height / 2
                color: Ui.alpha(Colors.overSurface, 0.7)
            }
            Rectangle {
                width: root.width * 0.16
                height: Math.max(2, root.unit * 0.45)
                radius: height / 2
                color: Ui.alpha(Colors.overSurface, 0.35)
            }
        }
    }

    // a toast in the top-right corner
    Rectangle {
        visible: root.value === "corner" || root.auto
        opacity: root.auto ? 0.45 : 1
        x: root.width - width - root.unit * 0.8
        y: root.auto ? root.height - height - root.unit * 0.8 : root.unit * 0.8
        width: root.width * 0.38
        height: root.unit * 2.8
        radius: Math.min(Styling.radius(-4), root.unit)
        color: Colors.surfaceContainerHighest
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.5)

        Rectangle {
            x: root.unit * 0.6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.unit * 1.2
            height: Math.max(2, root.unit * 0.45)
            radius: height / 2
            color: Ui.alpha(Colors.overSurface, 0.6)
        }
    }

    // tanzaku strips hanging from the top edge
    Row {
        visible: root.value === "strips"
        x: root.width - width - root.unit * 1.2
        y: 0
        spacing: root.unit * 0.6

        Repeater {
            model: [0.62, 0.8, 0.5]
            delegate: Rectangle {
                required property real modelData
                required property int index
                width: root.unit * 1.3
                height: root.height * modelData
                color: index === 1 ? Colors.primaryContainer : Colors.surfaceContainerHighest
                border.width: 1
                border.color: Ui.alpha(Colors.outlineVariant, 0.5)
            }
        }
    }

    Text {
        visible: root.auto
        anchors.centerIn: parent
        text: Icons.magicWand
        font.family: Icons.font
        font.pixelSize: Math.round(root.unit * 3)
        color: Colors.primary
    }
}
