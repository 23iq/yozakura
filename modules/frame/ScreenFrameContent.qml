import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.corners
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.globals

Item {
    id: root

    required property ShellScreen targetScreen
    property bool hasFullscreenWindow: false

    // State source: Singletons and Registry
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property string barPos: barPanel && barPanel.barPosition !== undefined ? barPanel.barPosition : (Config.bar?.position ?? "top")
    readonly property string notchPos: Config.notchPosition ?? "top"
    
    readonly property var barPanel: Visibilities.barPanels[targetScreen.name]
    readonly property var dockPanel: Visibilities.dockPanels[targetScreen.name]
    
    // Effective Reveal States
    readonly property bool barReveal: barPanel ? barPanel.reveal : true
    readonly property bool dockReveal: dockPanel ? dockPanel.reveal : true
    readonly property bool notchReveal: barPanel ? barPanel.notchReveal : true

    // Hover States for Restoration Logic
    readonly property bool barHovered: barPanel ? (barPanel.barHoverActive || barPanel.notchHoverActive || barPanel.notchOpen) : false
    readonly property bool dockHovered: dockPanel ? (dockPanel.reveal && (dockPanel.activeWindowFullscreen || dockPanel.keepHidden || !dockPanel.pinned)) : false

    // Sidebar State
    readonly property bool sidebarActive: GlobalStates.assistantVisible && targetScreen.name === GlobalStates.assistantScreenName
    readonly property bool sidebarPinned: GlobalStates.assistantPinned
    readonly property int sidebarWidth: GlobalStates.assistantEffectiveWidth
    readonly property string sidebarPosition: GlobalStates.assistantPosition

    readonly property int sidebarMargin: 4
    readonly property real baseThickness: {
        const base = Config.bar?.frameThickness ?? 6;
        return Math.max(0, Math.min(Math.round(base), 40));
    }

    // --- Animation Synchronization ---
    
    property real _barAnimProgress: barReveal ? 1.0 : 0.0
    Behavior on _barAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    property real _dockAnimProgress: dockReveal ? 1.0 : 0.0
    Behavior on _dockAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    property real _notchAnimProgress: notchReveal ? 1.0 : 0.0
    Behavior on _notchAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    // Frame growth swallowing contained panels (bar.containBar), per edge,
    // synchronized with each panel's reveal (PanelHost.containSides)
    readonly property var containTargets: barPanel && barPanel.panelContainSides ? barPanel.panelContainSides : ({})
    property real topContain: frameEnabled ? (containTargets.top || 0) : 0
    property real bottomContain: frameEnabled ? (containTargets.bottom || 0) : 0
    property real leftContain: frameEnabled ? (containTargets.left || 0) : 0
    property real rightContain: frameEnabled ? (containTargets.right || 0) : 0
    Behavior on topContain {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }
    Behavior on bottomContain {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }
    Behavior on leftContain {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }
    Behavior on rightContain {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }
    function containFor(side) {
        switch (side) {
        case "top":
            return topContain;
        case "bottom":
            return bottomContain;
        case "left":
            return leftContain;
        default:
            return rightContain;
        }
    }

    property real _sidebarAnimProgress: sidebarActive ? 1.0 : 0.0
    Behavior on _sidebarAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
    }

    // Sidebar expansion logic (synchronized with sidebar active and pinned)
    readonly property int sidebarExpansion: (frameEnabled && sidebarPinned) ? Math.round((sidebarWidth + baseThickness) * _sidebarAnimProgress) : 0

    // --- Side-Specific Thickness Restoration ---

    readonly property int topThickness: calculateSideThickness("top")
    readonly property int bottomThickness: calculateSideThickness("bottom")
    readonly property int leftThickness: calculateSideThickness("left")
    readonly property int rightThickness: calculateSideThickness("right")

    function calculateSideThickness(side) {
        let t = baseThickness;
        if (hasFullscreenWindow) {
            let restore = false;
            let progress = 0.0;

            if (barPos === side && barHovered) { restore = true; progress = Math.max(progress, _barAnimProgress); }
            if (notchPos === side && barHovered) { restore = true; progress = Math.max(progress, _notchAnimProgress); }
            if (dockPanel && dockPanel.position === side && dockHovered) { restore = true; progress = Math.max(progress, _dockAnimProgress); }
            
            t = restore ? (baseThickness * progress) : 0;
        }
        
        let expansion = Math.round(containFor(side));
        if (sidebarPosition === side) expansion += sidebarExpansion;
        return Math.round(t) + expansion;
    }

    // --- Corner Logic ---
    
    readonly property real targetInnerRadius: {
        if (!root.hasFullscreenWindow) return Styling.radius(4);
        if (!barHovered && !dockHovered) return 0;
        
        let progress = Math.max(_barAnimProgress, _dockAnimProgress, _notchAnimProgress);
        return Styling.radius(4) * progress;
    }
    
    property real innerRadius: targetInnerRadius

    // --- Visuals ---

    FrameFill {
        id: frameFill
        anchors.fill: parent
        visible: root.frameEnabled
        leftThickness: root.leftThickness
        topThickness: root.topThickness
        rightThickness: root.rightThickness
        bottomThickness: root.bottomThickness
        innerRadius: root.innerRadius
    }
}
