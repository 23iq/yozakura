pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

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

    // The persistent shell window was mapped before the AI window. Equal
    // Overlay layers leave a newly opened dashboard underneath fullscreen
    // AI, so yield both stacking and keyboard ownership to shell overlays.
    readonly property bool shellOverlayOpen: {
        if (!targetScreen)
            return false;
        const vis = Visibilities.getForScreen(targetScreen.name);
        return Visibilities.moduleNames.some(name => vis[name]);
    }

    // A grown notch (hover, player, notifications) draws below the bar,
    // inside fullscreen AI: AI drops a layer for it, keeping the keyboard.
    readonly property bool notchRaised: targetScreen ? Visibilities.hasNotch(targetScreen.name) && Visibilities.getForScreen(targetScreen.name).notchRaised : false

    onShellOverlayOpenChanged: if (shellOverlayOpen)
        grabbing = false

    function requestFocus() {
        if (shellOverlayOpen)
            return;
        grabbing = true;
        grabTimer.restart();
    }

    screen: targetScreen
    color: "transparent"
    visible: host.active || host.hitbox.visible
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: shellOverlayOpen || notchRaised ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("aicenter")
    WlrLayershell.keyboardFocus: !host.active || shellOverlayOpen ? WlrKeyboardFocus.None : (grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

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

    // Width the panel wants. The window widens at once but shrinks only after
    // the panel's own width animation, otherwise it would clip the glide.
    readonly property int wantedWidth: root.fullscreen ? (root.targetScreen ? root.targetScreen.width : 1920) : (host.resizing ? host.maxWidth : host.panelWidth) + host.sidebarMargin
    property int shownWidth: wantedWidth
    onWantedWidthChanged: {
        if (wantedWidth >= shownWidth || host.resizing) {
            shrinkTimer.stop();
            shownWidth = wantedWidth;
        } else {
            shrinkTimer.restart();
        }
    }
    implicitWidth: shownWidth

    Timer {
        id: shrinkTimer
        interval: Math.max(1, BarLook.animDuration) + 60
        onTriggered: root.shownWidth = root.wantedWidth
    }

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
