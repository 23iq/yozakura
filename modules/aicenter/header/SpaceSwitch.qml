pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common

// Segmented [Assistant | Code] control; the highlight slides between them.
StyledRect {
    id: root
    objectName: "spaceSwitch"

    readonly property var spaces: [
        {
            id: "assistant",
            icon: Icons.sparkle,
            label: I18n.t("ai.space_assistant")
        },
        {
            id: "code",
            icon: Icons.code,
            label: I18n.t("ai.space_code")
        }
    ]
    readonly property int current: GlobalStates.aiSpace === "code" ? 1 : 0
    property bool iconsOnly: false

    variant: "common"
    radius: Styling.radius(-2)
    implicitHeight: 32
    implicitWidth: segments.implicitWidth + 6

    StyledRect {
        id: highlight
        y: 3
        height: parent.height - 6
        readonly property Item target: repeater.count > root.current ? repeater.itemAt(root.current) : null
        width: target ? target.width : 0
        x: 3 + (target ? target.x : 0)
        variant: "focus"
        radius: Styling.radius(-4)
        Behavior on x {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                duration: BarLook.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }
        Behavior on width {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                duration: BarLook.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }
    }

    Row {
        id: segments
        x: 3
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            id: repeater
            model: root.spaces
            delegate: Item {
                id: segment
                required property var modelData
                required property int index
                width: content.implicitWidth + 20
                height: root.height - 6
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.icon
                        font.family: Icons.font
                        font.pixelSize: BarLook.font(-2)
                        color: segment.index === root.current ? Colors.primary : Colors.outline
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.iconsOnly
                        text: segment.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: BarLook.font(-2)
                        font.weight: segment.index === root.current ? Font.DemiBold : Font.Normal
                        color: segment.index === root.current ? Colors.overSurface : Colors.outline
                    }
                }
                MouseArea {
                    objectName: "space_" + segment.modelData.id
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ai.setSpace(segment.modelData.id)
                }
                StyledToolTip {
                    tooltipText: segment.modelData.label + " (Ctrl+" + (segment.index + 1) + ")"
                    show: root.iconsOnly && hoverArea.hovered
                }
                HoverHandler {
                    id: hoverArea
                }
            }
        }
    }
}
