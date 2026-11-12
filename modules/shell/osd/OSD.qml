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
import "OsdWindowBox.js" as OsdWindowBox

// On-screen display window: one per screen, covering it, with an input mask
// of just the OSD itself. The style (pill, edge, island) is a separate
// component loaded from OsdStyles; where it sits comes from EdgeService so it
// never lands on the bar. Scrolling over it changes the level, clicking opens
// the bar controls, hovering keeps it up. bar-inline renders in the bar
// instead (styles/OsdBarInline.qml) and leaves this window empty.
//
// performance.compactOsd: the window is sized to the OSD (OsdWindowBox.js)
// instead of the screen, anchored to the OSD's edge. Its geometry (and the
// OSD's place, size and form inside it) is taken only while the window is
// unmapped, never while it shows or animates: a layer surface resized per
// frame would reallocate its buffer every frame.
PanelWindow {
    id: root

    property ShellScreen targetScreen
    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("osd")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors.top: !root.layout.compact || root.layout.box.anchors.top
    anchors.bottom: !root.layout.compact || root.layout.box.anchors.bottom
    anchors.left: !root.layout.compact || root.layout.box.anchors.left
    anchors.right: !root.layout.compact || root.layout.box.anchors.right
    Binding {
        target: root
        property: "margins.top"
        value: root.layout.compact ? root.layout.box.margins.top : 0
    }
    Binding {
        target: root
        property: "margins.bottom"
        value: root.layout.compact ? root.layout.box.margins.bottom : 0
    }
    Binding {
        target: root
        property: "margins.left"
        value: root.layout.compact ? root.layout.box.margins.left : 0
    }
    Binding {
        target: root
        property: "margins.right"
        value: root.layout.compact ? root.layout.box.margins.right : 0
    }
    Binding {
        target: root
        property: "implicitWidth"
        when: root.layout.compact
        value: root.layout.compact ? root.layout.box.w : 1
    }
    Binding {
        target: root
        property: "implicitHeight"
        when: root.layout.compact
        value: root.layout.compact ? root.layout.box.h : 1
    }

    color: "transparent"
    visible: root.shown || motion.moving
    mask: Region {
        item: holder
    }

    property string kind: "volume"
    property real osdValue: 0
    property bool osdMuted: false
    property string device: ""

    readonly property var route: OsdService.routeForScreen(root.targetScreen ? root.targetScreen.name : "")
    readonly property string styleName: root.route.style
    readonly property string edgeName: OsdStyles.edgePref(root.styleName, Config.layout.osd.position, Config.notch.position, ShellLayout.notchEnabled, ShellLayout.barEnabled ? ShellLayout.layout.bar.edge : "")
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

    readonly property bool shown: GlobalStates.osdVisible && root.route.window

    // Where the OSD and the window are now (compact or not) ...
    readonly property bool compactWanted: Config.performance?.compactOsd ?? false
    readonly property var liveLayout: ({
            "compact": root.compactWanted,
            "x": root.place.x,
            "y": root.place.y,
            "size": root.size,
            "vertical": root.vertical,
            "slide": root.slide,
            "box": root.compactWanted ? OsdWindowBox.box(root.place, root.size, motion.distance, {
                "w": root.targetScreen ? root.targetScreen.width : 0,
                "h": root.targetScreen ? root.targetScreen.height : 0
            }, OsdWindowBox.shadowPad(Lighting.shadowXOffset, Lighting.shadowYOffset)) : null
        })
    // ... and what the window uses: compact geometry only changes while the
    // window is unmapped (the full-screen window follows live, as before)
    property var frozenLayout: root.liveLayout
    readonly property var layout: root.frozenLayout.compact || root.compactWanted ? root.frozenLayout : root.liveLayout
    function refreezeLayout(): void {
        if (!root.visible && JSON.stringify(root.frozenLayout) !== JSON.stringify(root.liveLayout))
            root.frozenLayout = root.liveLayout;
    }
    onLiveLayoutChanged: root.refreezeLayout()
    // Next tick: `visible` follows the motion, which follows the layout
    onVisibleChanged: Qt.callLater(root.refreezeLayout)
    Component.onCompleted: root.frozenLayout = root.liveLayout

    // Where the OSD sits (also its input region); `motion` fades and slides
    // it in from its edge on the render thread
    Item {
        id: holder
        x: root.layout.compact ? root.layout.box.offsetX : root.layout.x
        y: root.layout.compact ? root.layout.box.offsetY : root.layout.y
        width: root.layout.size.w
        height: root.layout.size.h

        OsdSlide {
            id: motion
            shown: root.shown
            slide: root.layout.slide

            Loader {
                id: styleLoader
                anchors.fill: parent
                source: root.route.window ? OsdStyles.fileFor(root.styleName) : ""
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
                    property: "currentDevice"
                    value: OsdService.currentDevice(root.kind)
                }
                Binding {
                    target: styleLoader.item
                    property: "vertical"
                    value: root.layout.vertical
                }
            }

            MouseArea {
                id: input
                objectName: "osdInput"
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
    }

    Timer {
        id: hideTimer
        interval: OsdService.timeout
        // Never under the pointer: a change or a wheel step while hovered
        // restarts the timer, leaving the OSD hides it
        onTriggered: {
            if (!input.containsMouse)
                GlobalStates.osdVisible = false;
        }
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
            if (root.route.window)
                root.show();
        }
    }
}
