import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

// Full-screen first-run wizard on the screen it opened on: a frosted scrim
// (the layer namespace gets the compositor blur) and the wizard card.
// Loaded by shell.qml while OnboardingService.visible; hidden (unmapped)
// while a keybind-tour panel is open (OnboardingService.suspended).
PanelWindow {
    id: root

    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === OnboardingService.screenName) || Quickshell.screens[0] || null
    visible: !OnboardingService.suspended
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Qt.callLater(() => root.shown = true)

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.background
        opacity: root.shown ? 0.62 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 1.5
                easing.type: Easing.OutCubic
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
}
