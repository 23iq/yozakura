pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.globals
import qs.config

// The AI bar's own layer window, one per screen. It is exactly as big as the
// panel (the whole screen only in fullscreen), so it never captures input
// outside itself and never fights the shell panel for focus. Keyboard focus
// is requested (Exclusive) only until the compositor delivers it, then the
// window sits at OnDemand: clicking another app moves focus there and the
// panel does not steal it back.
PanelWindow {
    id: root

    required property var targetScreen
    // Per-edge space the bar panels reserve, {top, bottom, left, right}
    property var zones: ({})
    // Height of a pinned bottom dock the panel must stay above
    property int dockBottom: 0

    // Exclusive keyboard request in flight; always short-lived
    property bool grabbing: false
    readonly property bool hasKeyboard: host.Window.active

    readonly property bool onLeft: GlobalStates.assistantPosition === "left"
    readonly property bool fullscreen: GlobalStates.assistantFullscreen
    readonly property int frameInset: (Config.bar?.frameEnabled ?? false) && !GlobalStates.assistantPinned ? (Config.bar?.frameThickness ?? 6) : 0

    function requestFocus() {
        grabbing = true;
        grabTimer.restart();
    }

    screen: targetScreen
    color: "transparent"
    visible: host.active || host.hitbox.visible
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("aicenter")
    WlrLayershell.keyboardFocus: !host.active ? WlrKeyboardFocus.None : (grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

    anchors {
        top: true
        bottom: true
        left: root.fullscreen || root.onLeft
        right: root.fullscreen || !root.onLeft
    }

    // Layer-shell margins: the bar panels' reservations and the frame inset
    Binding {
        target: root
        property: "margins.top"
        value: root.frameInset + (root.zones.top ?? 0)
    }
    Binding {
        target: root
        property: "margins.bottom"
        value: root.frameInset + ((root.zones.bottom ?? 0) > 0 ? root.zones.bottom : root.dockBottom)
    }
    Binding {
        target: root
        property: "margins.left"
        value: (root.zones.left ?? 0) + (root.onLeft ? root.frameInset : 0)
    }
    Binding {
        target: root
        property: "margins.right"
        value: (root.zones.right ?? 0) + (root.onLeft ? 0 : root.frameInset)
    }

    // While the width handle is dragged the window stays at its widest, so the
    // pointer does not move with the edge it is resizing.
    implicitWidth: root.fullscreen ? 0 : (host.resizing ? host.maxWidth : host.panelWidth) + host.sidebarMargin

    onHasKeyboardChanged: if (hasKeyboard)
        grabbing = false

    Timer {
        id: grabTimer
        interval: 600
        onTriggered: root.grabbing = false
    }

    AiCenterHost {
        id: host
        targetScreen: root.targetScreen
        availableWidth: root.targetScreen ? root.targetScreen.width : 1920
        hasKeyboard: root.hasKeyboard
        onFocusWanted: root.requestFocus()
    }
}
