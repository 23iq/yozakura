pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The picked monitor's resolutions, biggest first, as a list that scrolls
// inside its card (with a fade at the foot while more is below); the
// chosen one is lit with a check.
Item {
    id: root

    property var options: []
    // the height of the whole list (the page grows its row to it where it can)
    readonly property real needed: list.contentHeight
    property string value: ""
    signal selected(string value)

    clip: true

    ListView {
        id: list
        anchors.fill: parent
        model: root.options
        boundsBehavior: Flickable.StopAtBounds
        spacing: Space.xs
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool chosen: modelData.value === root.value
            objectName: "resolution:" + modelData.value
            width: list.width
            height: Space.controlS

            Mark {
                anchors.fill: parent
                radius: Look.radius("control", height)
                color: row.chosen ? Qt.alpha(Type.accent, 0.16) : (area.containsMouse ? Look.raisedFill(true) : "transparent")
            }
            KitText {
                anchors.left: parent.left
                anchors.leftMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                font.weight: row.chosen ? Type.weight("title") : Type.weight("body")
                color: row.chosen ? Type.accent : Type.text
                text: row.modelData.label
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                Icon {
                    visible: row.chosen
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.check
                    role: "body"
                    tone: "accent"
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(row.modelData.value)
            }
        }
    }

    // more below
    Mark {
        visible: list.contentY < list.contentHeight - list.height - 1
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
