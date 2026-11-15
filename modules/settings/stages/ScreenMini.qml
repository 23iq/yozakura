pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "../SchemaUtil.js" as SchemaUtil
import "../../bar/panels/PanelLayout.js" as PanelLayout

// The shared screen miniature of the settings stages: your screen as the
// shell draws it, to one scale. The bars, the dock and the island (at rest)
// are the shell's own components (live/LiveScreen: the real panels laid out at the screen's
// native size, then scaled; LIVE PREVIEWS in modules/settings/AGENTS.md),
// so every module, icon, workspace indicator, clock face, style and colour
// is the real one, and a new module or style shows up here by itself.
// Layers, back to front: windows in the space everything else leaves
// (reserved space made visible), the screen frame, the panels, dock and
// island, the rounded screen corners, then the page's `overlay` (surfaces
// that open somewhere, in screen coordinates: `freeRect`, `islandRect`,
// `edgeDepth(edge)`). A page turns layers on and off (`showWindows`,
// `showDock`, `showIsland`) and marks parts with StageSpot. With
// `selectable`, a click on a panel emits `panelPicked(index)` (the bars
// editor's index) and `selectedPanel` is ringed; with `modulesClickable`
// every module of every bar is a button (`modulePicked(id)`); with
// `partsClickable` the island and the dock emit `partPicked(part)`.
Item {
    id: screen

    property bool showWindows: true
    // the windows fade back (a stage whose subject sits over them)
    property real windowsOpacity: 1
    property bool showDock: true
    property bool showIsland: true
    property bool selectable: false
    property int selectedPanel: -1
    // (kept for the stages that pass it: the bars draw their own surface)
    property real barOpacity: 0.82
    property real cornerRadius: Space.surfaceRadius
    // A part ringed in the accent: "island" | "dock" | "" (the page that
    // controls it).
    property string emphasis: ""
    // The island and the dock answer clicks (`partPicked`).
    property bool partsClickable: false
    // The bar's modules answer clicks (`modulePicked(id)`).
    property bool modulesClickable: false
    default property alias overlay: overlayLayer.data
    signal panelPicked(int index)
    signal partPicked(string part)
    signal modulePicked(string id)

    function get(key, fallback) {
        const v = SettingsStore.get(key);
        return v === undefined || v === null ? fallback : SchemaUtil.plain(v);
    }

    // The bar config as bar.json holds it (legacy keys or bar.panels).
    readonly property var bar: ({
            "position": screen.get("bar.position", "top"),
            "layout": screen.get("bar.layout", {}),
            "panels": screen.get("bar.panels", []),
            "screenList": screen.get("bar.screenList", [])
        })
    readonly property var panels: PanelLayout.normalize(screen.bar).panels.filter(p => p && p.enabled !== false)
    readonly property bool compact: screen.get("bar.compact", false) === true
    readonly property bool frame: screen.get("bar.frameEnabled", false) === true
    readonly property bool island: screen.get("notch.enabled", true) !== false

    // Native px -> miniature px: the overview screen's width (LiveTarget:
    // your screen's shape, at most 1280 px wide, so the parts read) onto this.
    readonly property real k: screen.width > 0 ? screen.width / LiveTarget.overviewWidth : 1
    // A readable unit for what pages draw in the overlay (toasts, widgets):
    // about a module of a bar at the scale of the stage.
    property real minUnit: Space.px(16)
    readonly property real unit: Math.max(screen.minUnit, Math.round(screen.width * 0.03)) * (screen.compact ? 0.86 : 1)
    readonly property real frameWidth: screen.frame ? Number(screen.get("bar.frameThickness", 6)) * screen.k : 0
    // Room the bars take on each edge (the frame excluded), stage px.
    readonly property var depths: ({
            "top": live.depth("top") * screen.k,
            "bottom": live.depth("bottom") * screen.k,
            "left": live.depth("left") * screen.k,
            "right": live.depth("right") * screen.k
        })

    // The dock on its edge (not when it lives inside the bar).
    readonly property bool dockOn: screen.showDock && live.dockOn
    readonly property string dockEdge: live.dockEdge
    // the shell's rounded screen corners (a tile that crops the screen sets false)
    property bool corners: screen.get("theme.enableCorners", true) !== false
    // the island's edge (on a side edge it stands upright: the live island)
    readonly property string islandEdge: ["bottom", "left", "right"].indexOf(screen.get("notch.position", "top")) >= 0 ? screen.get("notch.position", "top") : "top"
    // Room taken on an edge by the bars, the frame and the dock.
    function edgeDepth(edge) {
        return screen.frameWidth + (screen.depths[edge] || 0) + (screen.dockOn && screen.dockEdge === edge ? live.dockDepth * screen.k : 0);
    }
    // The space windows get: {x, y, w, h}.
    readonly property var freeRect: {
        const l = screen.edgeDepth("left"), t = screen.edgeDepth("top");
        return {
            "x": l,
            "y": t,
            "w": screen.width - l - screen.edgeDepth("right"),
            "h": screen.height - t - screen.edgeDepth("bottom")
        };
    }
    readonly property var islandRect: ({
            "x": island.x,
            "y": island.y,
            "w": island.width,
            "h": island.height
        })

    // Where the panels and their modules are, in stage px (measured on the
    // live panels after each change: `refresh()`).
    property var panelRects: []
    property var moduleRects: []
    function refresh() {
        // (torn down with the page: nothing to measure)
        if (typeof live.bars.modules !== "function")
            return;
        const b = live.bars;
        const k = screen.k;
        const scaled = r => ({
                    "x": r.x * k,
                    "y": r.y * k,
                    "w": r.width * k,
                    "h": r.height * k
                });
        const all = b.panels;
        const pr = [];
        for (let i = 0; i < all.length; i++) {
            const r = b.panelRect(i);
            if (r.width > 0 && r.height > 0)
                pr.push(Object.assign({
                    "index": i
                }, scaled(r)));
        }
        screen.panelRects = pr;
        screen.moduleRects = b.modules().map(m => {
            const p = m.item.mapToItem(live, 0, 0);
            return Object.assign({
                "id": m.id,
                "panel": m.panel
            }, scaled(Qt.rect(p.x, p.y, m.item.width, m.item.height)));
        });
    }
    Timer {
        id: refreshTimer
        interval: 120
        onTriggered: screen.refresh()
    }
    function scheduleRefresh() {
        refreshTimer.restart();
    }
    onWidthChanged: screen.scheduleRefresh()
    onHeightChanged: screen.scheduleRefresh()
    onDepthsChanged: screen.scheduleRefresh()
    Connections {
        target: live.bars
        function onBarsChanged() {
            screen.scheduleRefresh();
        }
    }
    // fresh places whenever the pointer arrives (a module grew meanwhile)
    HoverHandler {
        onHoveredChanged: if (hovered)
            screen.refresh()
    }

    // A change of the arrangement settles it in again (a soft fade).
    readonly property string signature: JSON.stringify([screen.panels, screen.compact, screen.dockOn, screen.dockEdge])
    property real settle: 1
    onSignatureChanged: {
        settleAnim.restart();
        screen.scheduleRefresh();
    }
    NumberAnimation {
        id: settleAnim
        target: screen
        property: "settle"
        from: 0
        to: 1
        duration: Math.max(1, Motion.glide.duration)
        easing.type: Motion.glide.easing
    }

    // Two windows in the space the bars leave.
    ScreenWindows {
        frame: screen
        free: screen.freeRect
        unit: screen.unit
        shown: screen.showWindows
        shownOpacity: screen.windowsOpacity
    }

    // The screen frame.
    Mark {
        anchors.fill: parent
        visible: screen.frame
        radius: screen.cornerRadius
        color: "transparent"
        border.width: screen.frameWidth
        border.color: Colors.background

        StageSpot {
            keys: ["bar.frameEnabled", "bar.containBar"]
            cornerRadius: screen.cornerRadius
        }
    }

    // The bars and the dock: the shell's own, at the screen's size, scaled.
    Item {
        id: sandbox
        width: LiveTarget.overviewWidth
        height: screen.k > 0 ? screen.height / screen.k : 0
        scale: screen.k
        transformOrigin: Item.TopLeft
        opacity: 0.25 + 0.75 * screen.settle

        LiveScreen {
            id: live
            objectName: "screenMiniLive"
            anchors.fill: parent
            showDock: screen.showDock
            showIsland: screen.showIsland
            islandScreen: LiveTarget.overview
        }
    }

    // Each panel and module: its spot, the picked ring, the clicks.
    ScreenTargets {
        anchors.fill: parent
        panelRects: screen.panelRects
        moduleRects: screen.moduleRects
        selectable: screen.selectable
        selectedPanel: screen.selectedPanel
        modulesClickable: screen.modulesClickable
        onPanelPicked: index => screen.panelPicked(index)
        onModulePicked: id => screen.modulePicked(id)
    }

    // The dock: its spot and ring (the dock itself is in the live layer).
    Item {
        id: dock
        readonly property rect r: screen.dockOn ? live.dockRect() : Qt.rect(0, 0, 0, 0)
        visible: screen.dockOn
        x: dock.r.x * screen.k
        y: dock.r.y * screen.k
        width: dock.r.width * screen.k
        height: dock.r.height * screen.k

        StageSpot {
            keys: ["dock"]
        }
        Mark {
            anchors.fill: parent
            anchors.margins: -Space.xs
            visible: screen.emphasis === "dock"
            radius: Space.smallRadius + Space.xs
            color: "transparent"
            border.width: Space.stroke - 1
            border.color: Type.accent
        }
    }

    // The island (the real one is in the live layer): its spot and ring.
    Item {
        id: island
        readonly property rect r: live.islandOn ? live.islandRect() : Qt.rect(0, 0, 0, 0)
        visible: screen.showIsland && screen.island && live.islandOn
        x: island.r.x * screen.k
        y: island.r.y * screen.k
        width: island.r.width * screen.k
        height: island.r.height * screen.k
        readonly property real radius: Math.min(width, height) / 2

        StageSpot {
            keys: ["notch"]
            cornerRadius: island.radius
        }
        Mark {
            anchors.fill: parent
            anchors.margins: -Space.xs
            visible: screen.emphasis === "island"
            radius: island.radius + Space.xs
            color: "transparent"
            border.width: Space.stroke - 1
            border.color: Type.accent
        }
    }

    // Rounded screen corners (theme.enableCorners): the shell's own.
    Item {
        width: LiveTarget.overviewWidth
        height: sandbox.height
        scale: screen.k
        transformOrigin: Item.TopLeft
        visible: screen.corners
        Loader {
            anchors.fill: parent
            active: screen.corners && Number(screen.get("theme.roundness", 0)) > 0
            source: Qt.resolvedUrl("../../corners/ScreenCornersContent.qml")
        }
    }

    // The page's own layer (surfaces opening somewhere).
    Item {
        id: overlayLayer
        anchors.fill: parent
    }

    // With `partsClickable`: the island and the dock are buttons over
    // everything (a hover ring, then `partPicked("island" | "dock")`); the
    // part the page is about (`emphasis`) is not.
    Repeater {
        model: screen.partsClickable ? [
            {
                "part": "island",
                "item": island
            },
            {
                "part": "dock",
                "item": dock
            }
        ] : []
        delegate: MouseArea {
            id: partArea
            required property var modelData
            readonly property Item target: modelData.item
            objectName: "stagePart:" + modelData.part
            visible: partArea.target.visible && screen.emphasis !== modelData.part
            x: partArea.target.x
            y: partArea.target.y
            width: partArea.target.width
            height: partArea.target.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: screen.partPicked(partArea.modelData.part)

            Mark {
                anchors.fill: parent
                anchors.margins: -Space.xs
                radius: Math.min(width, height) / 2
                color: "transparent"
                border.width: Space.stroke - 1
                border.color: Type.accent
                opacity: partArea.containsMouse ? 0.8 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.micro.duration
                        easing.type: Motion.micro.easing
                    }
                }
            }
        }
    }
}
