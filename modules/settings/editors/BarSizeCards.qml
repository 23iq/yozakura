pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Bar size as bars of growing height (bar.compact: S = compact, M =
// regular); the chosen one in the accent. Left / Right on keyboard.
FocusScope {
    id: root

    property var entry
    readonly property bool compact: SettingsStore.get("bar.compact") === true
    readonly property var sizes: [
        {
            "label": "S",
            "compact": true,
            "h": 0.62
        },
        {
            "label": "M",
            "compact": false,
            "h": 1
        }
    ]

    // the card's height (SettingRow.fillHeight): the bars grow from its foot
    property real fillHeight: 0
    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 1.6
    activeFocusOnTab: true
    Keys.onLeftPressed: SettingsStore.set("bar.compact", true)
    Keys.onRightPressed: SettingsStore.set("bar.compact", false)

    Row {
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Space.m

        Repeater {
            model: root.sizes
            delegate: Mark {
                id: size
                required property var modelData
                readonly property bool chosen: modelData.compact === root.compact
                objectName: "barSize:" + modelData.label
                width: (root.width - Space.m * (root.sizes.length - 1)) / root.sizes.length
                height: root.implicitHeight * modelData.h
                anchors.bottom: parent.bottom
                radius: Look.radius("box", height)
                color: size.chosen ? Type.accent : Look.raisedFill(area.containsMouse)
                Behavior on color {
                    enabled: Motion.micro.duration > 0
                    ColorAnimation {
                        duration: Motion.micro.duration
                    }
                }
                KitText {
                    anchors.centerIn: parent
                    role: "title"
                    color: size.chosen ? Colors.overPrimary : Type.secondary
                    text: size.modelData.label
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsStore.set("bar.compact", size.modelData.compact)
                }
            }
        }
    }
    FocusRing {
        shown: root.activeFocus
        radius: Look.radius("box", Space.controlL)
    }
}
