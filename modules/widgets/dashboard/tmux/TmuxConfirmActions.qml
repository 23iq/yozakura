pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Cancel / confirm button pair shown at the right of a session row while it
// is being renamed or deleted. Slides in when `active`; the highlight
// stretches between the buttons as `buttonIndex` (0 cancel, 1 confirm)
// changes. Hovering a button reports its index through `hoverIndex`.
Rectangle {
    id: actions

    property bool active: false
    property int buttonIndex: 0
    property string highlightVariant: "overerror"
    property color iconColor: Colors.overError
    property color highlightedIconColor: Colors.overErrorContainer

    signal cancelClicked
    signal confirmClicked
    signal hoverIndex(int index)

    width: 68
    height: 32
    color: "transparent"
    opacity: actions.active ? 1.0 : 0.0
    visible: opacity > 0

    transform: Translate {
        x: actions.active ? 0 : 80

        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }
    }

    StyledRect {
        id: highlight
        variant: actions.highlightVariant
        radius: Styling.radius(-4)
        visible: actions.active
        z: 0

        property real activeButtonMargin: 2
        property real idx1X: actions.buttonIndex
        property real idx2X: actions.buttonIndex

        x: Math.min(highlight.idx1X, highlight.idx2X) * 36 + highlight.activeButtonMargin // 32 + 4 spacing
        y: highlight.activeButtonMargin
        width: Math.abs(highlight.idx1X - highlight.idx2X) * 36 + 32 - highlight.activeButtonMargin * 2
        height: 32 - highlight.activeButtonMargin * 2

        Behavior on idx1X {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2X {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: [
                {
                    icon: Icons.cancel
                },
                {
                    icon: Icons.accept
                }
            ]

            delegate: Rectangle {
                id: button

                required property var modelData
                required property int index
                readonly property bool isHighlighted: actions.buttonIndex === button.index

                width: 32
                height: 32
                color: "transparent"
                radius: 6
                border.width: 0
                border.color: Colors.outline
                z: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: button.index === 0 ? actions.cancelClicked() : actions.confirmClicked()
                    onEntered: actions.hoverIndex(button.index)
                    onExited: button.color = "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData.icon
                    color: button.isHighlighted ? actions.highlightedIconColor : actions.iconColor
                    font.pixelSize: 14
                    font.family: Icons.font
                    textFormat: Text.RichText

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }
        }
    }
}
