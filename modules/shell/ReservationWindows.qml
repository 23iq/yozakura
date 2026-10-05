import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.services
import qs.modules.globals

Item {
    id: root

    required property ShellScreen screen

    // These properties are bound from shell.qml
    // Space the bar panels reserve per edge (PanelHost.zones, frame excluded)
    property var panelZones: ({
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        })

    property bool dockEnabled: true
    property string dockPosition: "bottom"
    property bool dockPinned: true
    property int dockHeight: 0

    property bool frameEnabled: false
    property int frameThickness: 6

    property bool sidebarEnabled: false
    property bool sidebarPinned: false
    property int sidebarWidth: 0
    property string sidebarPosition: "right"

    readonly property int sidebarMargin: 4

    readonly property int actualFrameSize: frameEnabled ? frameThickness : 0

    // Exclusive zones per edge (also read by the wallpaper's coverage check)
    readonly property int topZone: topWindow.exclusiveZone
    readonly property int bottomZone: bottomWindow.exclusiveZone
    readonly property int leftZone: leftWindow.exclusiveZone
    readonly property int rightZone: rightWindow.exclusiveZone

    Component.onCompleted: Visibilities.registerReservation(root.screen.name, root)
    Component.onDestruction: Visibilities.registerReservation(root.screen.name, null)

    Item {
        id: noInputRegion
        width: 0
        height: 0
        visible: false
    }

    PanelWindow {
        id: topWindow
        screen: root.screen
        visible: true
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: Brand.namespace("reservation:top")
        
        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            zone += root.panelZones.top || 0;
            if (dockEnabled && dockPosition === "top" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: bottomWindow
        screen: root.screen
        visible: true
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            bottom: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: Brand.namespace("reservation:bottom")

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            zone += root.panelZones.bottom || 0;
            if (dockEnabled && dockPosition === "bottom" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: leftWindow
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: Brand.namespace("reservation:left")

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            zone += root.panelZones.left || 0;
            if (sidebarEnabled && sidebarPosition === "left" && sidebarPinned) {
                zone += sidebarWidth;
                zone += frameEnabled ? actualFrameSize : sidebarMargin;
            }
            if (dockEnabled && dockPosition === "left" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: rightWindow
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: Brand.namespace("reservation:right")

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            zone += root.panelZones.right || 0;
            if (sidebarEnabled && sidebarPosition === "right" && sidebarPinned) {
                zone += sidebarWidth;
                zone += frameEnabled ? actualFrameSize : sidebarMargin;
            }
            if (dockEnabled && dockPosition === "right" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }
}
