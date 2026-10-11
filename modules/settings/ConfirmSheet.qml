pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
import qs.modules.theme

// A small modal question over the settings window: a title, a sentence and
// one to three actions (`actions`: [{id, text, kind}], the last is the
// primary one). `chosen(id)` fires for a button; Escape or a click on the
// scrim emits `dismissed()`. Shown while `open`.
Item {
    id: root

    property bool open: false
    property string title: ""
    property string body: ""
    property var actions: []

    signal chosen(string id)
    signal dismissed

    // Strength of the dimming over the page (a scrim role at this opacity).
    readonly property real scrimOpacity: 0.5

    visible: open
    z: 50
    focus: open

    Keys.onEscapePressed: root.dismissed()
    onOpenChanged: if (open)
        card.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: root.scrimOpacity

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }
    }

    Surface {
        id: card
        objectName: "confirmCard"
        anchors.centerIn: parent
        width: Math.min(root.width - Space.xxl * 2, Space.px(440))
        focus: true
        Keys.onEscapePressed: root.dismissed()

        // Clicks on the card never reach the scrim.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            width: parent.width
            spacing: Space.m

            KitText {
                width: parent.width
                role: "title"
                text: root.title
                wrapMode: Text.WordWrap
            }
            KitText {
                width: parent.width
                role: "secondary"
                text: root.body
                visible: text !== ""
                wrapMode: Text.WordWrap
            }
            Row {
                anchors.right: parent.right
                spacing: Space.s

                Repeater {
                    model: root.actions

                    delegate: PillButton {
                        required property var modelData
                        objectName: "confirm:" + modelData.id
                        kind: modelData.kind ?? "tonal"
                        text: modelData.text
                        onClicked: root.chosen(modelData.id)
                    }
                }
            }
        }
    }
}
