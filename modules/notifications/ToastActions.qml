pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit

// A notification's actions as kit Chips in a wrapping row, left aligned at
// their natural width (ToastCard, the notch's CompactNotification).
// `primaryFirst`: the first action is the surface's one filled accent
// action (the notch, where quiet ink chips would read as loose text).
Flow {
    id: root

    property var actions: []
    property bool primaryFirst: false

    signal invoked(string identifier)

    spacing: Space.s

    Repeater {
        model: root.actions

        Chip {
            objectName: "notificationAction"
            required property var modelData
            required property int index
            primary: root.primaryFirst && index === 0
            text: modelData.text
            onClicked: root.invoked(modelData.identifier)
        }
    }
}
