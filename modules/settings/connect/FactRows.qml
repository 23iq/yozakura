pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit

// A details card's facts: label on the left, value on the right, one per
// line, hairlines between (`facts`: [[label, value]]; empty values are
// skipped).
Column {
    id: root

    property var facts: []

    Repeater {
        model: root.facts.filter(f => f[1] !== "" && f[1] !== undefined && f[1] !== null)
        delegate: Item {
            required property var modelData
            required property int index
            width: root.width
            height: Space.controlS
            Divider {
                visible: parent.index > 0
                width: parent.width
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: parent.modelData[0]
            }
            KitText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                text: String(parent.modelData[1])
            }
        }
    }
}
