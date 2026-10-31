import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.controls

// theme.lighting live: a bar strip and a panel casting the effective shadow
// (Lighting.qml, the same values the shell uses), their lit top edge, and a
// dial showing where the light comes from.
PreviewStage {
    id: root

    property var entry
    stageHeight: 150

    readonly property var light: Lighting.light
    // Screen direction the light comes from (opposite of the shadow)
    readonly property real lightX: root.light ? -root.light.dx : 0
    readonly property real lightY: root.light ? -root.light.dy : -1

    Row {
        anchors.centerIn: parent
        spacing: Space.xl

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.l

            StyledRect {
                objectName: "previewBar"
                variant: "barbg"
                glassSurface: "bar"
                enableShadow: true
                width: Space.controlXL * 2
                height: Space.chip
                radius: Space.surfaceRadius
            }
            StyledRect {
                objectName: "previewPanel"
                variant: "popup"
                glassSurface: "popups"
                enableShadow: true
                width: Space.controlXL * 2
                height: Space.controlL
                radius: Space.surfaceRadius

                Column {
                    x: Space.m
                    y: Space.m
                    spacing: Space.s
                    Repeater {
                        model: [0.62, 0.4]
                        Rectangle {
                            required property real modelData
                            width: Space.controlXL * 2 * modelData
                            height: Space.s
                            radius: height / 2
                            color: Look.alpha("overBackground", 0.35)
                        }
                    }
                }
            }
        }

        // Light dial: the ring is the sky around the screen, the dot the light
        Item {
            id: dial
            objectName: "lightDial"
            anchors.verticalCenter: parent.verticalCenter
            width: Space.controlL
            height: Space.controlL
            opacity: Lighting.active ? 1 : 0.4

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: Space.hairline
                border.color: Type.hairline
            }
            Rectangle {
                width: Space.xs
                height: Space.xs
                radius: width / 2
                anchors.centerIn: parent
                color: Look.alpha("overBackground", 0.4)
            }
            Rectangle {
                readonly property real r: dial.width / 2 - Space.s
                width: Space.s + Space.xs
                height: width
                radius: width / 2
                x: dial.width / 2 + root.lightX * r - width / 2
                y: dial.height / 2 + root.lightY * r - height / 2
                color: Lighting.edgeColor
                visible: Lighting.active
                Behavior on x {
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
            }
        }
    }
}
