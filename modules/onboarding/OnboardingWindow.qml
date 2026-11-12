import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.globals

// Full-screen first-run wizard on the screen it opened on: a frosted scrim
// (the layer namespace gets the compositor blur) and the wizard card.
// Loaded by shell.qml while OnboardingService.visible; hidden (unmapped)
// while peeking (OnboardingService.peek), while a live display change
// waits for "Keep these display settings?" (the prompt is an Overlay layer
// too, so the wizard steps aside instead of racing it for the top) and
// while an app install waits for the password at an external polkit
// agent: its dialog is a normal window, under this Overlay layer and
// without keyboard focus while it holds the exclusive focus. The shell's
// own agent (PolkitService.registered) opens its dialog above the wizard
// instead; the wizard stays and hands it the keyboard while it is open.
PanelWindow {
    id: root

    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === OnboardingService.screenName) || Quickshell.screens[0] || null
    visible: !OnboardingService.peek && !(DisplaysService.pending && DisplaysService.session.live) && !(ExtrasService.awaitingAuth && !PolkitService.registered)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("onboarding")
    WlrLayershell.keyboardFocus: PolkitService.dialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    Component.onCompleted: Qt.callLater(() => root.shown = true)

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.background
        opacity: root.shown ? 0.62 : 0
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    OnboardingFlow {
        id: flow
        anchors.fill: parent
        shown: root.shown
        focus: true
        onCloseRequested: OnboardingService.complete()
    }

    onVisibleChanged: if (visible)
        flow.forceActiveFocus()

    // The keyboard comes back from the password dialog
    Connections {
        target: PolkitService
        function onDialogOpenChanged() {
            if (!PolkitService.dialogOpen && root.visible)
                flow.forceActiveFocus();
        }
    }
}
