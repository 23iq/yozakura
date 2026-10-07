pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Cancel / confirm pair that slides in at the right edge of a row (delete
// and alias modes). `buttonIndex` (0 cancel, 1 confirm) drives the highlight,
// which stretches between the two buttons while it moves.
Rectangle {
    id: actions

    property bool shown: false
    property string highlightVariant: "overerror"
    property int buttonIndex: 0
    property color idleColor
    property color activeColor

    signal hovered(int index)
    signal cancelled
    signal confirmed

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 8
    color: "transparent"
    opacity: actions.shown ? 1.0 : 0.0
    visible: opacity > 0

    transform: Translate {
        x: actions.shown ? 0 : 80

        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Motion.morph.easing
            }
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Motion.enter.easing
        }
    }

    StyledRect {
        variant: actions.highlightVariant
        radius: Styling.radius(-4)
        visible: actions.shown
        z: 0

        property real activeButtonMargin: 2
        property real idx1X: actions.buttonIndex
        property real idx2X: actions.buttonIndex

        x: Math.min(idx1X, idx2X) * 36 + activeButtonMargin
        y: activeButtonMargin
        width: Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2
        height: 32 - activeButtonMargin * 2

        Behavior on idx1X {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Motion.morph.easing
            }
        }
        Behavior on idx2X {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Motion.morph.easing
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: [Icons.cancel, Icons.accept]

            delegate: Rectangle {
                id: button

                required property string modelData
                required property int index
                readonly property bool isHighlighted: actions.buttonIndex === button.index

                width: 32
                height: 32
                color: "transparent"
                radius: 6
                z: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: button.index === 0 ? actions.cancelled() : actions.confirmed()
                    onEntered: actions.hovered(button.index)
                    onExited: button.color = "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData
                    color: button.isHighlighted ? actions.activeColor : actions.idleColor
                    font.pixelSize: 14
                    font.family: Icons.font
                    textFormat: Text.RichText

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Motion.morph.easing
                        }
                    }
                }
            }
        }
    }
}
