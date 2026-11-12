import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The empty converter: the window's hero, one inset drop target with a
// quiet outline that turns accent with "Release to add" while files are
// dragged over the window (`dragging`). One short line, then the other
// ways in: click to choose (clicked()) or Ctrl+V.
Item {
    id: root

    property bool dragging: false
    property string message: ""
    readonly property real radius: Look.radius("box", height)

    signal clicked

    Well {
        objectName: "dropWell"
        anchors.fill: parent
        radius: root.radius
        border.width: root.dragging ? Space.stroke : Space.hairline
        border.color: root.dragging ? Type.accent : (mouse.containsMouse ? Type.muted : Type.track)

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    Mark {
        objectName: "dropWash"
        anchors.fill: parent
        radius: root.radius
        color: Type.accent
        opacity: root.dragging ? 0.12 : (mouse.containsMouse ? 0.04 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Space.l

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.dragging ? Icons.arrowFatLinesDown : Icons.swap
            size: Space.controlL
            tone: root.dragging ? "accent" : "muted"
        }

        KitText {
            objectName: "dropText"
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            role: "title"
            color: root.dragging ? Type.accent : Type.text
            text: root.dragging ? I18n.t("converter.drop_release") : I18n.t("converter.drop_hint")
        }

        // click to choose · paste [Ctrl] [V]
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.dragging
            spacing: Space.s

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: I18n.t("converter.drop_click")
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                color: Type.muted
                text: "·"
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: I18n.t("converter.drop_paste")
            }

            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                text: "Ctrl"
            }

            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                text: "V"
            }
        }

        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width - Space.xxl * 2)
            visible: root.message !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            role: "caption"
            color: Type.danger
            text: root.message
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
