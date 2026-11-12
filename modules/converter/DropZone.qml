import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The empty converter: one large inset zone with an icon and one line
// (drop, paste or click). A click opens the file chooser (clicked()); the
// accent wash while files are dragged over the window is `dragging`.
Item {
    id: root

    property bool dragging: false
    property string message: ""

    signal clicked

    Well {
        anchors.fill: parent
        radius: Look.radius("group", height)
    }

    Mark {
        objectName: "dropWash"
        anchors.fill: parent
        radius: Look.radius("group", height)
        color: Type.accent
        opacity: root.dragging ? 0.14 : (mouse.containsMouse ? 0.05 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Space.xl * 2
        spacing: Space.m

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.dragging ? Icons.arrowFatLinesDown : Icons.swap
            size: Space.controlL
            tone: root.dragging ? "accent" : "muted"
        }

        KitText {
            objectName: "dropText"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            role: "body"
            text: root.dragging ? I18n.t("converter.drop_release") : I18n.t("converter.drop_hint")
        }

        KitText {
            width: parent.width
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
