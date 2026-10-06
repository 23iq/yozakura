import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.bar.panels
import qs.modules.bar.activities
import qs.modules.bar.workspaces
import qs.modules.notch
import qs.modules.dock
import qs.modules.frame
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.config
import qs.modules.aicenter
import qs.modules.notifications
import qs.modules.shell.rehome

PanelWindow {
    id: unifiedPanel

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // Dynamic keyboard focus: Exclusive when a notch module is open (so text fields work),
    // None otherwise (so compositor receives normal input).
    WlrLayershell.keyboardFocus: {
        if (notchContent.screenNotchOpen || notchContent.panelModal) {
            return WlrKeyboardFocus.Exclusive;
        }
        if (assistantSidebar.active && assistantSidebar.wantsFocus) {
            return WlrKeyboardFocus.Exclusive;
        }
        return WlrKeyboardFocus.None;
    }
    WlrLayershell.namespace: Brand.namespace("")
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Whether we need to capture full-screen input for click-outside detection.
    // True when notch modules are open OR any FocusGrab is active (e.g., BarPopups).
    readonly property bool needsFullScreenInput: notchContent.screenNotchOpen || notchContent.panelModal || FocusGrabManager.hasActiveGrab || (assistantSidebar.active && assistantSidebar.wantsFocus)

    // Bar panels of this screen (bar.panels, or the legacy bar); the
    // primary one is what the notch, frame and activities pair with
    readonly property var barContent: panelHost.primary
    readonly property bool barEnabled: Config.barReady && barContent !== null

    readonly property bool dockEnabled: {
        if (!Config.dockReady) return false;
        if (!(Config.dock.enabled ?? false) || (Config.dock.theme ?? "default") === "integrated")
            return false;
        const list = Config.dock.screenList;
        return (!list || list.length === 0 || list.indexOf(targetScreen.name) !== -1);
    }

    readonly property string barPosition: barContent ? barContent.barPosition : Panels.primaryEdge
    // A panel that hides itself ("always") still counts as pinned for the
    // notch: only the shared pin makes the notch follow the bar
    readonly property bool barPinned: barContent ? (barContent.pinned || barContent.autohideMode === "always") : true
    readonly property bool barHoverActive: barContent ? barContent.hoverActive : false
    readonly property bool barFullscreen: barContent ? barContent.activeWindowFullscreen : false
    readonly property bool barReveal: barEnabled && barContent.reveal
    readonly property int barTargetWidth: barContent ? barContent.barTargetWidth : 0
    readonly property int barTargetHeight: barContent ? barContent.barTargetHeight : 0
    readonly property int barOuterMargin: barContent ? barContent.baseOuterMargin : 0
    // Per-edge window reservation and frame growth of every panel
    readonly property var panelZones: panelHost.zones
    readonly property var panelContainSides: panelHost.containSides

    readonly property alias dockPosition: dockContent.position
    readonly property alias dockPinned: dockContent.pinned
    readonly property bool dockReveal: dockEnabled && dockContent.reveal
    readonly property alias dockFullscreen: dockContent.activeWindowFullscreen
    readonly property int dockHeight: dockContent.dockSize + dockContent.totalMargin

    readonly property alias notchHoverActive: notchContent.hoverActive
    readonly property alias notchOpen: notchContent.screenNotchOpen
    readonly property alias notchReveal: notchContent.reveal

    // Generic names for external compatibility (Visibilities expects these on the panel object)
    readonly property bool pinned: barPinned
    readonly property bool reveal: barEnabled ? barContent.reveal : false
    readonly property bool hoverActive: barHoverActive // Default hoverActive points to bar
    readonly property alias notch_hoverActive: notchContent.hoverActive // Used by bar to check notch

    readonly property bool unifiedEffectActive: false // Flag to notify children to disable internal borders

    readonly property var compositorMonitor: YozdService.monitorFor(targetScreen)
    // Fullscreen detection - scoped to this monitor so the effect only
    // applies to the screen that actually has the fullscreen window
    readonly property bool hasFullscreenWindow: CompositorData.monitorHasFullscreen(compositorMonitor)

    // Proxy properties for Bar/Notch synchronization
    // Note: BarContent and NotchContent already handle their internal sync using Visibilities.

    // Helper properties for shadow logic
    readonly property bool keepBarShadow: Config.bar.keepBarShadow ?? false
    readonly property bool keepBarBorder: Config.bar.keepBarBorder ?? false
    readonly property bool containBar: barContent ? barContent.contained : false

    Component.onCompleted: {
        Visibilities.registerBarPanel(screen.name, unifiedPanel);
        Visibilities.registerNotchPanel(screen.name, unifiedPanel);
        Visibilities.registerDockPanel(screen.name, dockContent);
        Visibilities.registerNotch(screen.name, notchContent.notchContainerRef);
        Visibilities.registerDock(screen.name, dockContent);
    }

    onBarContentChanged: Visibilities.registerBar(screen.name, barContent)

    Component.onDestruction: {
        Visibilities.unregisterBarPanel(screen.name);
        Visibilities.unregisterNotchPanel(screen.name);
        Visibilities.unregisterDockPanel(screen.name);
        Visibilities.unregisterBar(screen.name);
        Visibilities.unregisterNotch(screen.name);
        Visibilities.unregisterDock(screen.name);
    }

    // Full-screen mask item (used when modules/popups are open)
    Item {
        id: fullScreenMask
        anchors.fill: parent
    }

    // Mask Region Logic
    // When a module or popup is open, expand to full-screen to capture click-outside.
    // Otherwise, restrict input to Bar, Notch, and Dock hitboxes only.
    mask: Region {
        // Full-screen capture when any module/popup is open
        item: unifiedPanel.needsFullScreenInput ? fullScreenMask : null
        regions: [unifiedPanel.notchRegion, unifiedPanel.dockRegion, unifiedPanel.assistantRegion, unifiedPanel.activityLeftRegion, unifiedPanel.activityRightRegion, unifiedPanel.toastRegion, unifiedPanel.cornerPillsRegion].concat(panelHost.hitRegions)
    }

    readonly property Region notchRegion: Region {
        // A disabled notch takes input only while it shows a view
        item: ShellLayout.notchEnabled || notchContent.reveal ? notchContent.notchHitbox : null
    }
    readonly property Region dockRegion: Region {
        // Only include the dock hitbox if the dock is actually enabled and visible on this screen.
        item: dockContent.visible ? dockContent.dockHitbox : null
    }
    readonly property Region assistantRegion: Region {
        item: (assistantSidebar.active || assistantSidebar.hitbox.visible) ? assistantSidebar.hitbox : null
    }
    readonly property Region activityLeftRegion: Region {
        item: activityHost.leftHitbox
    }
    readonly property Region activityRightRegion: Region {
        item: activityHost.rightHitbox
    }
    readonly property Region toastRegion: Region {
        item: cornerToasts.active ? cornerToasts.hitbox : null
    }
    readonly property Region cornerPillsRegion: Region {
        item: cornerPills.hitbox
    }

    // Focus Grab for Notch — registers with FocusGrabManager for click-outside coordination
    FocusGrab {
        id: focusGrab
        windows: [unifiedPanel]
        active: notchContent.screenNotchOpen || notchContent.panelModal

        onCleared: {
            Visibilities.setActiveModule("");
            notchContent.dismissPanel();
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CLICK-OUTSIDE BACKDROP
    // ═══════════════════════════════════════════════════════════════

    // Transparent backdrop that captures clicks on empty areas when modules/popups are open.
    // z: -1 ensures it's below all visual content (bar, notch, dock).
    MouseArea {
        id: backdropArea
        anchors.fill: parent
        visible: unifiedPanel.needsFullScreenInput
        z: -1

        onClicked: {
            FocusGrabManager.clearTopGrab();
            if (notchContent.panelModal)
                notchContent.dismissPanel();
            if (assistantSidebar.active && assistantSidebar.wantsFocus) {
                assistantSidebar.wantsFocus = false;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VISUAL CONTENT
    // ═══════════════════════════════════════════════════════════════

    Item {
        id: visualContent
        anchors.fill: parent

        // Shadows below every surface, each re-rendered on its own
        PanelShadows {
            anchors.fill: parent
            z: 0
            frame: frameContent
            bars: panelHost.bars
            notch: notchContent
            dock: dockContent
            activities: activityHost
            sidebar: assistantSidebar
            barEnabled: unifiedPanel.barEnabled
            dockEnabled: unifiedPanel.dockEnabled
        }

        ScreenFrameContent {
            id: frameContent
            anchors.fill: parent
            targetScreen: unifiedPanel.targetScreen
            hasFullscreenWindow: unifiedPanel.hasFullscreenWindow
            z: 1
        }

        PanelHost {
            id: panelHost
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            active: Config.barReady
            z: 2
        }

        DockContent {
            id: dockContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 3
            visible: unifiedPanel.dockEnabled
        }

        // Live activities next to the notch
        ActivityHost {
            id: activityHost
            anchors.fill: parent
            screenName: unifiedPanel.targetScreen.name
            bar: unifiedPanel.barContent
            notch: notchContent
            barEnabled: unifiedPanel.barEnabled
            z: 3
        }

        NotchContent {
            id: notchContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 4
        }

        // Re-homed content when the bar and/or notch are off (ShellLayout)
        CornerPills {
            id: cornerPills
            anchors.fill: parent
            panel: unifiedPanel
            z: 5
        }

        // Corner toasts (notifications.presentation "corner")
        CornerToasts {
            id: cornerToasts
            anchors.fill: parent
            panel: unifiedPanel
            notch: notchContent
            screenName: unifiedPanel.targetScreen.name
            z: 5
        }

        AiCenterHost {
            id: assistantSidebar
            targetScreen: unifiedPanel.targetScreen
            z: 1
            
            // Respect top/bottom bar reservations so the sidebar doesn't overlap them
            anchors.topMargin: {
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = (frameOn && !frameWrapped) ? (Config.bar?.frameThickness ?? 6) : 0;
                margin += unifiedPanel.panelZones.top;
                return margin;
            }
            
            anchors.bottomMargin: {
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = (frameOn && !frameWrapped) ? (Config.bar?.frameThickness ?? 6) : 0;
                if (unifiedPanel.panelZones.bottom > 0) {
                    margin += unifiedPanel.panelZones.bottom;
                } else if (unifiedPanel.dockEnabled && dockContent.dockPosition === "bottom" && dockContent.pinned) {
                    margin += dockContent.dockHeight;
                }
                return margin;
            }

            anchors.leftMargin: {
                let sidebarPos = GlobalStates.assistantPosition;
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = 0;
                if (sidebarPos === "left" && frameOn && !frameWrapped)
                    margin += (Config.bar?.frameThickness ?? 6);
                margin += unifiedPanel.panelZones.left;
                return margin;
            }

            anchors.rightMargin: {
                let sidebarPos = GlobalStates.assistantPosition;
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = 0;
                if (sidebarPos === "right" && frameOn && !frameWrapped)
                    margin += (Config.bar?.frameThickness ?? 6);
                margin += unifiedPanel.panelZones.right;
                return margin;
            }
        }
    }
}
