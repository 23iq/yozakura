pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.shell.osd
import qs.modules.services
import qs.modules.globals
import qs.modules.shell
import qs.config
import "OsdStyles.js" as OsdStyles

// On-screen display window: one per screen, covering it, with an input mask
// of just the OSD itself. The style (pill, edge, island) is a separate
// component loaded from OsdStyles; where it sits comes from EdgeService so it
// never lands on the bar. Scrolling over it changes the level, clicking opens
// the bar controls, hovering keeps it up. bar-inline renders in the bar
// instead (styles/OsdBarInline.qml) and leaves this window empty.
PanelWindow {
    id: root

    property ShellScreen targetScreen
    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("osd")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: (GlobalStates.osdVisible && OsdService.route.window) || holder.opacity > 0
    mask: Region {
        item: holder
    }

    property string kind: "volume"
    property real osdValue: 0
    property bool osdMuted: false
    property string device: ""

    readonly property string styleName: OsdService.route.style
    readonly property string edgeName: OsdStyles.edgePref(root.styleName, Config.layout.osd.position, Config.notch.position)
    readonly property bool vertical: EdgeService.osdPlacement(root.targetScreen, root.edgeName, {
        "w": 1,
        "h": 1
    }).vertical
    readonly property var size: OsdStyles.sizeFor(root.styleName, root.vertical, Metrics.osdW)
    readonly property var place: EdgeService.osdPlacement(root.targetScreen, root.edgeName, root.size)
    // Direction the OSD slides in from, towards its own edge.
    readonly property point slide: ({
            "top": Qt.point(0, -1),
            "bottom": Qt.point(0, 1),
            "left": Qt.point(-1, 0),
            "right": Qt.point(1, 0)
        })[root.place.edge] ?? Qt.point(0, 1)

    function show(): void {
        GlobalStates.osdVisible = true;
        hideTimer.restart();
    }

    Item {
        id: holder
        x: root.place.x + root.slide.x * 14 * (1 - opacity)
        y: root.place.y + root.slide.y * 14 * (1 - opacity)
        width: root.size.w
        height: root.size.h
        opacity: GlobalStates.osdVisible && OsdService.route.window ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: GlobalStates.osdVisible ? OsdMotion.enterMs : OsdMotion.exitMs
                easing.type: GlobalStates.osdVisible ? OsdMotion.enterEasing : OsdMotion.exitEasing
            }
        }

        Loader {
            id: styleLoader
            anchors.fill: parent
            source: OsdService.route.window ? OsdStyles.fileFor(root.styleName) : ""
            onLoaded: item.shown = Qt.binding(() => GlobalStates.osdVisible)

            Binding {
                target: styleLoader.item
                property: "kind"
                value: root.kind
            }
            Binding {
                target: styleLoader.item
                property: "value"
                value: root.osdValue
            }
            Binding {
                target: styleLoader.item
                property: "muted"
                value: root.osdMuted
            }
            Binding {
                target: styleLoader.item
                property: "device"
                value: root.device
            }
            Binding {
                target: styleLoader.item
                property: "vertical"
                value: root.vertical
            }
        }

        MouseArea {
            id: input
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: containsMouse ? hideTimer.stop() : hideTimer.restart()
            onWheel: wheel => {
                OsdService.adjust(root.kind, OsdStyles.wheelStep(wheel.angleDelta.y), root.targetScreen);
                hideTimer.restart();
            }
            onClicked: {
                GlobalStates.osdVisible = false;
                OsdService.openControls(root.targetScreen ? root.targetScreen.name : "");
            }
        }
    }

    Timer {
        id: hideTimer
        interval: OsdService.timeout
        onTriggered: GlobalStates.osdVisible = false
    }

    // A device name is shown briefly, then the label returns.
    Timer {
        id: deviceTimer
        interval: 1500
        onTriggered: root.device = ""
    }

    Connections {
        target: OsdService

        function onLevel(kind, value, muted, device) {
            if (kind === "brightness" && OsdService.lastScreen && root.targetScreen && OsdService.lastScreen !== root.targetScreen.name && !Brightness.syncBrightness)
                return;
            root.kind = kind;
            root.osdValue = value;
            root.osdMuted = muted;
            GlobalStates.osdIndicator = kind;
            if (device !== "") {
                root.device = device;
                deviceTimer.restart();
            }
            if (OsdService.route.window)
                root.show();
        }
    }
}
