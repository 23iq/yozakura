pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The list of a connect page's card (Wi-Fi networks, Bluetooth devices,
// audio devices): rows of a glyph, a name, a state line and a trailing
// mark, the picked one washed in the accent; it scrolls inside its card
// with a fade at the foot while more is below. `rows`: [{key, icon, title,
// line, on, trailing}] (icon / trailing: Icons names). `empty`: what an
// empty list says.
Item {
    id: root

    property var rows: []
    property string current: ""
    property string empty: ""
    property real fillHeight: 0
    signal picked(string key)

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3
    clip: true

    KitText {
        anchors.centerIn: parent
        visible: root.rows.length === 0
        role: "secondary"
        text: root.empty
    }

    ListView {
        id: list
        objectName: "deviceList"
        anchors.fill: parent
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        spacing: Space.xs
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool chosen: modelData.key === root.current
            objectName: "deviceRow:" + modelData.key
            width: list.width
            height: Space.controlM + Space.s

            Mark {
                anchors.fill: parent
                radius: Look.radius("control", height)
                color: row.chosen ? Qt.alpha(Type.accent, 0.16) : (area.containsMouse ? Look.raisedFill(true) : "transparent")
            }
            Icon {
                id: glyph
                x: Space.m
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons[row.modelData.icon] ?? Icons.circle
                role: "title"
                tone: row.modelData.on ? "accent" : "secondary"
            }
            Column {
                anchors.left: glyph.right
                anchors.leftMargin: Space.m
                anchors.right: tail.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                KitText {
                    width: parent.width
                    role: "body"
                    elide: Text.ElideRight
                    font.weight: row.modelData.on ? Type.weight("title") : Type.weight("body")
                    text: row.modelData.title
                }
                KitText {
                    width: parent.width
                    visible: text !== ""
                    role: "caption"
                    color: row.modelData.on ? Type.accent : Type.secondary
                    elide: Text.ElideRight
                    text: row.modelData.line || ""
                }
            }
            Icon {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                visible: (row.modelData.trailing || "") !== ""
                icon: Icons[row.modelData.trailing || "circle"] ?? ""
                role: "caption"
                tone: "muted"
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(row.modelData.key)
            }
        }
    }

    // more below
    Mark {
        visible: list.contentHeight > list.height && list.contentY < list.contentHeight - list.height - 1
        anchors.bottom: parent.bottom
        width: parent.width
        height: Space.l
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Look.cardFill(false)
            }
        }
    }
}
