pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../live/LiveKeys.js" as ScreenParts

// ScreenMini's bar targets, over the live panels (rects in the miniature,
// measured by ScreenMini.refresh): each panel's spot, the picked ring and,
// with `selectable`, a click that picks it (`panelPicked(index)`); each
// module's spot and, with `modulesClickable`, a button to its card
// (`modulePicked(id)`).
Item {
    id: targets

    property var panelRects: []
    property var moduleRects: []
    property bool selectable: false
    property int selectedPanel: -1
    property bool modulesClickable: false
    signal panelPicked(int index)
    signal modulePicked(string id)

    Repeater {
        model: targets.panelRects
        delegate: Item {
            id: panelPart
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            StageSpot {
                keys: ["bar.layout", "bar.position", "bar.compact", "bar.panels", "bar.pinnedOnStartup", "bar.showPinButton", "bar.availableOnFullscreen", "bar.screenList"]
                cornerRadius: Space.smallRadius
            }
            // the panel picked for editing (ringed), or under the pointer
            // (a fainter ring: it can be picked)
            Mark {
                anchors.fill: parent
                anchors.margins: -Space.xs
                readonly property bool picked: targets.selectable && targets.selectedPanel === panelPart.modelData.index
                opacity: picked ? 1 : (panelArea.containsMouse ? 0.55 : 0)
                visible: opacity > 0
                radius: Space.smallRadius + Space.xs
                color: "transparent"
                border.width: Space.stroke - 1
                border.color: Type.accent
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                        easing.type: Motion.micro.easing
                    }
                }
            }
            MouseArea {
                id: panelArea
                objectName: "barPanel:" + panelPart.modelData.index
                anchors.fill: parent
                enabled: targets.selectable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: targets.panelPicked(panelPart.modelData.index)
            }
        }
    }

    Repeater {
        model: targets.moduleRects
        delegate: Item {
            id: modulePart
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            StageSpot {
                keys: ScreenParts.moduleKeys(modulePart.modelData.id)
            }
            MouseArea {
                id: moduleArea
                objectName: "barModule:" + modulePart.modelData.id
                anchors.fill: parent
                enabled: targets.modulesClickable
                visible: enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: targets.modulePicked(modulePart.modelData.id)

                // under the pointer: a soft wash (a click goes to its card)
                Mark {
                    anchors.fill: parent
                    radius: Space.smallRadius
                    color: Qt.alpha(Type.accent, 0.18)
                    opacity: moduleArea.containsMouse ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        enabled: Motion.micro.duration > 0
                        NumberAnimation {
                            duration: Motion.micro.duration
                            easing.type: Motion.micro.easing
                        }
                    }
                }
            }
        }
    }
}
