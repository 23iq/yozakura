import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

// Full-screen "Keep these display settings?" prompt, loaded on every screen
// while a live layout change is pending (DisplaysService.pending). Enter keeps, Esc
// reverts; the backend reverts by itself when the countdown ends.
PanelWindow {
    id: root

    property ShellScreen targetScreen
    property bool shown: false

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("displays-confirm")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        card.takeFocus();
        Qt.callLater(() => root.shown = true);
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: root.shown ? 0.6 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    DisplayConfirmCard {
        id: card
        anchors.centerIn: parent
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.94
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 1.2
                easing.type: Motion.morph.easing
                easing.overshoot: 1.2
            }
        }
    }

    // A click outside the card keeps the focus on the choice
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: card.takeFocus()
    }
}
