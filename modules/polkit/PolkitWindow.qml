import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.modules.globals
import qs.modules.components.kit

// The password prompt's surface: a full-screen Overlay layer on the
// screen the request opened on, with exclusive keyboard focus and a
// dimmed backdrop. Created when a request needs the user, so it maps last
// and sits above every other shell surface. While it is open the setup
// wizard gives its keyboard focus up, the open shell module closes and
// none opens, and keybinds run only commands that map no surface
// (PolkitService.dialogOpen / allowsCommand). A click on the backdrop keeps
// the request (it only refocuses the field).
PanelWindow {
    id: root

    property ShellScreen targetScreen
    property AuthFlow flow
    property bool shown: false

    screen: root.targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("polkit")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Qt.callLater(() => root.shown = true)

    Scrim {
        shown: root.shown
        strength: 0.6
        onClicked: dialog.focusField()
    }

    PolkitDialog {
        id: dialog
        anchors.centerIn: parent
        flow: root.flow
        shown: root.shown
    }
}
