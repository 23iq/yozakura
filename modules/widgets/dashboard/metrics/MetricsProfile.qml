pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.globals
import qs.modules.components.kit
import "MetricsModel.js" as MetricsModel

// Who and where: the user's avatar (click to pick another) beside the
// user name, the host name and the OS with its logo.
RowLayout {
    id: root

    property string hostname: ""
    property string osName: ""
    // Nerd Font glyph of the OS ("" = none known yet)
    property string osLogo: ""

    // One line of the card: a glyph and its text.
    component InfoLine: RowLayout {
        id: line

        property string icon: ""
        property string family: Icons.font
        property string text: ""

        Layout.fillWidth: true
        spacing: Space.xs

        Icon {
            icon: line.icon
            font.family: line.family
            role: "body"
            tone: "secondary"
            Layout.preferredWidth: Type.iconSize("body")
        }

        KitText {
            Layout.fillWidth: true
            role: "body"
            text: line.text
        }
    }

    spacing: Space.l

    Item {
        Layout.preferredWidth: Space.controlXL
        Layout.preferredHeight: Space.controlXL

        Avatar {
            id: avatar
            objectName: "metricsAvatar"
            anchors.fill: parent
            source: `file://${Quickshell.env("HOME")}/.face.icon?${GlobalStates.avatarCacheBuster}`
            opacity: avatarMouse.containsMouse ? 0.8 : 1

            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                }
            }
        }

        MouseArea {
            id: avatarMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: GlobalStates.pickUserAvatar()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Space.xs

        InfoLine {
            icon: Icons.user
            text: MetricsModel.capitalize(Quickshell.env("USER") || "user")
        }

        InfoLine {
            icon: Icons.at
            text: root.hostname ? MetricsModel.capitalize(root.hostname.toLowerCase()) : "Hostname"
        }

        InfoLine {
            icon: root.osLogo
            family: "Symbols Nerd Font Mono"
            text: root.osName || "Linux"
        }
    }
}
