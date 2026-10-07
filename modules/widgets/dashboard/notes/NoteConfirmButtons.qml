pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Cancel / confirm icon pair shown on a note row in delete or rename mode,
// with a highlight that slides to the keyboard-selected button
// (buttonIndex: 0 = cancel, 1 = confirm). Slides in from the right.
Item {
    id: buttons

    property bool shown: false
    property int buttonIndex: 0
    property string highlightVariant: "overerror"
    property color iconColor: Colors.overError
    property color highlightedIconColor: Colors.overErrorContainer

    signal cancelClicked
    signal confirmClicked
    signal buttonHovered(int index)

    width: 68
    height: 32
    opacity: buttons.shown ? 1.0 : 0.0
    visible: opacity > 0

    transform: Translate {
        x: buttons.shown ? 0 : 80

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
        id: highlight
        variant: buttons.highlightVariant
        radius: Styling.radius(-4)
        visible: buttons.shown
        z: 0

        property real activeButtonMargin: 2
        property real idx1X: buttons.buttonIndex
        property real idx2X: buttons.buttonIndex

        x: Math.min(highlight.idx1X, highlight.idx2X) * 36 + highlight.activeButtonMargin
        y: highlight.activeButtonMargin
        width: Math.abs(highlight.idx1X - highlight.idx2X) * 36 + 32 - highlight.activeButtonMargin * 2
        height: 32 - highlight.activeButtonMargin * 2

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

            delegate: Item {
                id: button

                required property string modelData
                required property int index
                readonly property bool isHighlighted: buttons.buttonIndex === button.index

                width: 32
                height: 32
                z: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: button.index === 0 ? buttons.cancelClicked() : buttons.confirmClicked()
                    onEntered: buttons.buttonHovered(button.index)
                }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData
                    color: button.isHighlighted ? buttons.highlightedIconColor : buttons.iconColor
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
