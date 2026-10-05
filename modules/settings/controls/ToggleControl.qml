import QtQuick
import qs.modules.theme
import qs.config
import "../Ui.js" as Ui

// Switch. `toggled(value)` fires on user interaction only; `checked`
// follows the bound value.
Item {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked

    function flip() {
        if (enabled)
            toggled(!checked);
    }

    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colors.primary : Ui.alpha(Colors.overBackground, 0.14)
        border.width: root.checked ? 0 : 1
        border.color: Ui.alpha(Colors.outline, 0.6)
        opacity: root.enabled ? 1 : 0.4

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }

        Rectangle {
            id: knob
            readonly property real pad: root.checked ? 3 : 5
            width: parent.height - pad * 2
            height: width
            radius: width / 2
            y: pad
            x: root.checked ? parent.width - width - pad : pad
            color: root.checked ? Colors.overPrimary : Colors.outline

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: Icons.accept
                font.family: Icons.font
                font.pixelSize: parent.width * 0.62
                color: Colors.primary
                opacity: root.checked ? 1 : 0
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
        visible: root.activeFocus
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.flip();
        }
    }
}
