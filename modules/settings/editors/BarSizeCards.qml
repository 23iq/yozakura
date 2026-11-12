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
            "label": "prefs.bar.size.compact",
            "compact": true,
            "h": 0.72
        },
        {
            "label": "prefs.bar.size.regular",
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
        width: parent.width
        spacing: Space.m

        Repeater {
            model: root.sizes
            // a tile per size: a mini bar at its real relative thickness
            // over a strip of desktop, the name under it; the chosen one ringed
            delegate: Mark {
                id: size
                required property var modelData
                readonly property bool chosen: modelData.compact === root.compact
                objectName: "barSize:" + (modelData.compact ? "compact" : "regular")
                width: (root.width - Space.m * (root.sizes.length - 1)) / root.sizes.length
                height: root.implicitHeight
                radius: Look.radius("box", height)
                color: Look.raisedFill(area.containsMouse)
                border.width: size.chosen ? Space.stroke - 1 : Space.hairline
                border.color: size.chosen ? Type.accent : Type.hairline

                Mark {
                    id: miniBar
                    x: Space.s
                    y: Space.s
                    width: parent.width - Space.s * 2
                    height: Math.round(Space.controlM * size.modelData.h)
                    radius: Look.radius("small", height)
                    color: size.chosen ? Qt.alpha(Type.accent, 0.85) : Colors.surfaceContainerHighest
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Space.s
                        spacing: Space.xs
                        Repeater {
                            model: 3
                            delegate: Mark {
                                width: Math.round(miniBar.height * 0.4)
                                height: width
                                color: size.chosen ? Colors.overPrimary : Type.secondary
                            }
                        }
                    }
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Space.s
                    role: "body"
                    font.weight: size.chosen ? Font.DemiBold : Font.Normal
                    color: size.chosen ? Type.text : Type.secondary
                    text: I18n.t(size.modelData.label)
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
