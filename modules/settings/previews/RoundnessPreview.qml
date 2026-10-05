import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.settings.controls
import "../Ui.js" as Ui

// Shell surfaces drawn with the live roundness (Styling.radius follows
// Config.roundness, which the slider updates as it moves).
PreviewStage {
    id: root

    property var entry
    stageHeight: 150

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6
        spacing: 18

        // Window
        StyledRect {
            variant: "pane"
            width: 170
            height: 96
            radius: Styling.radius(4)
            enableShadow: false

            Rectangle {
                id: windowOutline
                anchors.fill: parent
                radius: Styling.radius(4)
                color: "transparent"
                border.width: 1
                border.color: Ui.alpha(Colors.outlineVariant, 0.7)
            }

            Row {
                x: 12
                y: 12
                spacing: 5
                Repeater {
                    model: 3
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: Ui.alpha(Colors.overSurfaceVariant, 0.5)
                    }
                }
            }
            Column {
                x: 12
                y: 32
                spacing: 7
                Rectangle {
                    width: 110
                    height: 7
                    radius: Math.min(3.5, Styling.radius(-12))
                    color: Ui.alpha(Colors.overBackground, 0.8)
                }
                Rectangle {
                    width: 80
                    height: 6
                    radius: Math.min(3, Styling.radius(-12))
                    color: Ui.alpha(Colors.overSurfaceVariant, 0.45)
                }
                Rectangle {
                    width: 60
                    height: 22
                    radius: Styling.radius(-4)
                    color: Colors.primary
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Bar pill
            StyledRect {
                variant: "common"
                width: 150
                height: 30
                radius: Styling.radius(0)
                enableShadow: false
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: index === 1 ? 22 : 10
                            height: 10
                            radius: Styling.radius(-10)
                            color: index === 1 ? Colors.primary : Ui.alpha(Colors.overSurfaceVariant, 0.5)
                        }
                    }
                }
            }
            // Button + chip
            Row {
                spacing: 8
                StyledRect {
                    variant: "primary"
                    width: 82
                    height: 30
                    radius: Styling.radius(-2)
                    enableShadow: false
                    Text {
                        anchors.centerIn: parent
                        text: Styling.radius(0) + " px"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Bold
                        color: Colors.overPrimary
                    }
                }
                StyledRect {
                    variant: "focus"
                    width: 60
                    height: 30
                    radius: Styling.radius(-2)
                    enableShadow: false
                }
            }
        }
    }
}
