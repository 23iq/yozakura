pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../PanelSketch.js" as PanelSketch
import "../SchemaUtil.js" as SchemaUtil
import "../../bar/panels/PanelLayout.js" as PanelLayout
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles

// The shared screen miniature of the settings stages: your whole screen
// arrangement at once and to one scale, from the live config. Layers, back
// to front: windows in the space everything else leaves (reserved space
// made visible), the screen frame and rounded corners, every bar panel by
// its style and edge (PanelSketch.js: several bars, vertical rails,
// islands, floating docks; the real clock face and workspace indicator),
// the dock on its edge, the island, then the page's `overlay` (surfaces
// that open somewhere, drawn in screen coordinates: `freeRect`,
// `islandRect`, `edgeDepth(edge)`). A page turns layers on and off
// (`showWindows`, `showDock`, `showIsland`) and marks parts with
// StageSpot (keys below). With `selectable`, a click on a panel emits
// `panelPicked(index)` and `selectedPanel` is ringed in the accent.
// Any change of the arrangement settles it in again (a soft fade).
Item {
    id: screen

    property bool showWindows: true
    property bool showDock: true
    property bool showIsland: true
    property bool selectable: false
    property int selectedPanel: -1
    // The bar surface is drawn at least this opaque (see Stage.barOpacity).
    property real barOpacity: 0.82
    property real cornerRadius: Space.surfaceRadius
    default property alias overlay: overlayLayer.data
    signal panelPicked(int index)

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
    readonly property bool showDate: screen.get("bar.clockShowDate", false) === true
    readonly property bool use12h: screen.get("bar.use12hFormat", false) === true
    readonly property string face: screen.get("bar.moduleOptions.clock.face", "digital")
    readonly property int workspaces: Math.max(1, Math.min(6, Number(screen.get("workspaces.shown", 5))))
    readonly property bool numbers: screen.get("workspaces.showNumbers", true) !== false
    readonly property string numerals: screen.get("workspaces.numeralStyle", WorkspaceNumerals.DEFAULT_ID)
    readonly property string indicator: screen.get("workspaces.indicatorStyle", IndicatorStyles.DEFAULT_ID)
    readonly property bool island: screen.get("notch.enabled", true) !== false

    // Module size in stage pixels: a bar of a 1920 px screen at the scale
    // of the stage, never so small that a glyph stops reading.
    readonly property real unit: Math.max(Space.px(16), Math.round(screen.width * 0.03)) * (screen.compact ? 0.86 : 1)
    readonly property real frameWidth: screen.frame ? Math.max(Space.xs, Math.round(screen.unit * 0.3)) : 0
    // Slots the wide modules take (the real clock and workspace strip).
    readonly property var spans: ({
            "clock": 2.3 + (screen.use12h ? 1.1 : 0) + (screen.showDate ? 2 : 0),
            "workspaces": screen.workspaces * 0.85 + 0.3
        })
    readonly property real innerWidth: screen.width - screen.frameWidth * 2
    readonly property real innerHeight: screen.height - screen.frameWidth * 2
    readonly property var sketches: screen.panels.map(p => PanelSketch.sketch(p, screen.innerWidth, screen.innerHeight, screen.unit, screen.spans))
    readonly property var depths: {
        const d = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        const n = Math.min(screen.panels.length, screen.sketches.length);
        for (let i = 0; i < n; i++)
            d[screen.panels[i].edge] = Math.max(d[screen.panels[i].edge], screen.sketches[i].depth);
        return d;
    }

    // The dock on its edge (not when it lives inside the bar).
    readonly property bool dockOn: screen.showDock && screen.get("dock.enabled", true) !== false && screen.get("dock.theme", "default") !== "integrated"
    readonly property string dockEdge: screen.get("dock.position", "bottom")
    readonly property bool dockFloating: screen.get("dock.theme", "default") === "floating"
    readonly property real dockThick: Math.round(screen.unit * Math.max(1.2, Number(screen.get("dock.height", 48)) / 30))
    readonly property real dockGap: Math.round(screen.unit * (screen.dockFloating ? 0.5 : 0.2))
    readonly property bool corners: screen.get("theme.enableCorners", true) !== false
    readonly property string islandEdge: screen.get("notch.position", "top") === "bottom" ? "bottom" : "top"
    // Room taken on an edge by the bars, the frame and the dock.
    function edgeDepth(edge) {
        return screen.frameWidth + (screen.depths[edge] || 0) + (screen.dockOn && screen.dockEdge === edge ? screen.dockThick + screen.dockGap * 2 : 0);
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

    // A change of the bar settles it in again (a soft fade and lift).
    readonly property string signature: JSON.stringify([screen.panels, screen.compact, screen.spans, screen.dockOn, screen.dockEdge, screen.dockThick])
    property real settle: 1
    onSignatureChanged: settleAnim.restart()
    NumberAnimation {
        id: settleAnim
        target: screen
        property: "settle"
        from: 0
        to: 1
        duration: Math.max(1, Motion.glide.duration)
        easing.type: Motion.glide.easing
    }

    // Two windows in the space the bar leaves.
    Item {
        id: windows
        readonly property real gap: Math.round(screen.unit * 0.5)
        visible: screen.showWindows
        x: screen.freeRect.x + gap
        y: screen.freeRect.y + gap
        width: screen.freeRect.w - gap * 2
        height: screen.freeRect.h - gap * 2
        Behavior on x {
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        Repeater {
            model: [[0, 0.58], [0.58, 0.42]]
            delegate: Mark {
                required property var modelData
                required property int index
                x: modelData[0] * windows.width + (index > 0 ? windows.gap / 2 : 0)
                width: modelData[1] * windows.width - windows.gap / 2
                height: windows.height
                radius: Space.smallRadius
                color: Qt.alpha(Colors.surfaceContainer, 0.62)
                border.width: Space.hairline
                border.color: Qt.alpha(index === 0 ? Colors.primary : Colors.outlineVariant, 0.55)

                // a title line and a few text lines
                Column {
                    x: windows.gap
                    y: windows.gap
                    spacing: Math.round(windows.gap * 0.6)
                    Repeater {
                        model: 4
                        delegate: Mark {
                            required property int index
                            width: (index === 0 ? 0.3 : 0.62 - index * 0.08) * windows.width * 0.5
                            height: Math.max(2, Math.round(screen.unit * 0.18))
                            color: Qt.alpha(Colors.overSurface, index === 0 ? 0.5 : 0.22)
                        }
                    }
                }
            }
        }
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

    // The bar (every panel).
    Item {
        id: barLayer
        x: screen.frameWidth
        y: screen.frameWidth
        width: screen.innerWidth
        height: screen.innerHeight
        opacity: 0.25 + 0.75 * screen.settle
        transform: Translate {
            y: (1 - screen.settle) * -Space.s
        }

        Repeater {
            model: screen.sketches
            delegate: Item {
                id: panel
                required property var modelData
                required property int index
                readonly property string edge: screen.panels[panel.index] ? screen.panels[panel.index].edge : "top"
                readonly property bool vertical: panel.edge === "left" || panel.edge === "right"
                anchors.fill: parent

                Repeater {
                    model: panel.modelData.shapes
                    // The ring sits beside the surface, not in it (a
                    // StyledRect clips its children to its shape).
                    delegate: Item {
                        required property var modelData
                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h

                        StyledRect {
                            id: shape
                            anchors.fill: parent
                            variant: "barbg"
                            backgroundOpacity: screen.barOpacity
                            enableShadow: false
                            radius: Math.min(parent.modelData.r, Styling.radius(0))
                        }
                        StageSpot {
                            keys: ["bar.layout", "bar.position", "bar.compact", "bar.panels", "bar.pinnedOnStartup", "bar.showPinButton", "bar.availableOnFullscreen", "bar.screenList"]
                            cornerRadius: shape.radius
                        }
                        // the panel picked for editing
                        Mark {
                            anchors.fill: parent
                            anchors.margins: -Space.xs
                            visible: screen.selectable && screen.selectedPanel === panel.index && screen.panels.length > 1
                            radius: shape.radius + Space.xs
                            color: "transparent"
                            border.width: Space.stroke - 1
                            border.color: Type.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: screen.selectable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: screen.panelPicked(panel.index)
                        }
                    }
                }

                Repeater {
                    model: panel.modelData.icons
                    delegate: Item {
                        id: slot
                        required property var modelData
                        readonly property bool wide: modelData.id === "clock" || modelData.id === "workspaces"
                        readonly property real along: slot.wide ? modelData.span : modelData.size
                        x: panel.vertical ? modelData.x : modelData.x + (modelData.size - slot.along) / 2
                        y: panel.vertical ? modelData.y + (modelData.size - slot.along) / 2 : modelData.y
                        width: panel.vertical ? modelData.size : slot.along
                        height: panel.vertical ? slot.along : modelData.size

                        Icon {
                            anchors.centerIn: parent
                            visible: !slot.wide
                            icon: Icons[slot.modelData.icon] ?? ""
                            size: Math.round(slot.modelData.size * 0.86)
                            tone: slot.modelData.id === "launcher" ? "accent" : "text"
                        }

                        // The real bar clock face, a fixed 21:47.
                        Row {
                            anchors.centerIn: parent
                            visible: slot.modelData.id === "clock"
                            spacing: Math.round(screen.unit * 0.3)
                            KitText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: screen.showDate && !panel.vertical
                                text: Qt.formatDate(new Date(2026, 3, 9), "ddd d")
                                color: Type.secondary
                                font.pixelSize: Math.round(screen.unit * 0.6)
                            }
                            Loader {
                                anchors.verticalCenter: parent.verticalCenter
                                active: slot.modelData.id === "clock"
                                source: Qt.resolvedUrl("../../bar/clock/ClockFace.qml")
                                onLoaded: {
                                    item.now = new Date(2026, 3, 9, 21, 47);
                                    item.textColor = Qt.binding(() => Colors.overBackground);
                                    item.fontSize = Qt.binding(() => Math.round(screen.unit * 0.66));
                                    item.face = Qt.binding(() => screen.face);
                                    item.use12h = Qt.binding(() => screen.use12h);
                                    item.vertical = Qt.binding(() => panel.vertical);
                                }
                            }
                        }
                        StageSpot {
                            visible: slot.modelData.id === "clock"
                            keys: ["bar.clockShowDate", "bar.use12hFormat", "bar.moduleOptions.clock"]
                        }

                        // Workspaces: your count and numerals, the real
                        // active indicator on the second one.
                        Grid {
                            id: strip
                            anchors.centerIn: parent
                            visible: slot.modelData.id === "workspaces"
                            columns: panel.vertical ? 1 : screen.workspaces
                            readonly property real cell: Math.round(screen.unit * 0.85)
                            Repeater {
                                model: slot.modelData.id === "workspaces" ? screen.workspaces : 0
                                delegate: Item {
                                    id: ws
                                    required property int index
                                    readonly property bool current: index === 1
                                    width: strip.cell
                                    height: strip.cell

                                    // A fake ActiveIndicator for the style component.
                                    QtObject {
                                        id: fake
                                        readonly property bool vertical: false
                                        readonly property real width: strip.cell
                                        readonly property real height: strip.cell
                                        readonly property real slotSize: strip.cell
                                        readonly property real padding: 0
                                        readonly property bool occupied: true
                                        readonly property real baseRadius: Styling.radius(0)
                                        readonly property int workspaceId: 2
                                    }
                                    Loader {
                                        active: ws.current
                                        source: {
                                            const s = IndicatorStyles.get(screen.indicator);
                                            return s && !s.strip ? Qt.resolvedUrl("../../bar/workspaces/indicators/" + s.component) : Qt.resolvedUrl("../../bar/workspaces/indicators/PillIndicator.qml");
                                        }
                                        onLoaded: item.indicator = fake
                                    }
                                    KitText {
                                        anchors.centerIn: parent
                                        visible: screen.numbers
                                        text: WorkspaceNumerals.format(screen.numerals, ws.index + 1)
                                        font.pixelSize: Math.round(screen.unit * 0.5)
                                        font.weight: Font.DemiBold
                                        color: ws.current ? Colors.primary : Qt.alpha(Colors.overBackground, ws.index < 3 ? 0.9 : 0.45)
                                    }
                                    Mark {
                                        anchors.centerIn: parent
                                        visible: !screen.numbers && !ws.current
                                        width: Math.round(strip.cell * 0.22)
                                        height: width
                                        color: Qt.alpha(Colors.overBackground, ws.index < 3 ? 0.8 : 0.35)
                                    }
                                }
                            }
                        }
                        StageSpot {
                            visible: slot.modelData.id === "workspaces"
                            keys: ["workspaces"]
                        }
                    }
                }
            }
        }
    }

    // The dock on its edge.
    Item {
        id: dock
        readonly property bool vertical: screen.dockEdge === "left" || screen.dockEdge === "right"
        readonly property real length: (dock.vertical ? screen.height : screen.width) * 0.34
        visible: screen.dockOn
        width: dock.vertical ? screen.dockThick : dock.length
        height: dock.vertical ? dock.length : screen.dockThick
        x: screen.dockEdge === "left" ? screen.frameWidth + (screen.depths.left || 0) + screen.dockGap : (screen.dockEdge === "right" ? screen.width - width - screen.frameWidth - (screen.depths.right || 0) - screen.dockGap : (screen.width - width) / 2)
        y: screen.dockEdge === "top" ? screen.frameWidth + (screen.depths.top || 0) + screen.dockGap : (screen.dockEdge === "bottom" ? screen.height - height - screen.frameWidth - (screen.depths.bottom || 0) - screen.dockGap : (screen.height - height) / 2)

        StyledRect {
            id: dockBox
            anchors.fill: parent
            variant: "bg"
            enableShadow: false
            radius: Math.min(Styling.radius(0), Math.min(width, height) / 2)
        }
        Grid {
            anchors.centerIn: parent
            rows: dock.vertical ? 6 : 1
            columns: dock.vertical ? 1 : 6
            spacing: Math.round(screen.dockThick * 0.22)
            Repeater {
                model: 6
                delegate: Mark {
                    required property int index
                    width: Math.round(screen.dockThick * 0.56)
                    height: width
                    radius: Look.radius("small", height)
                    color: index === 0 ? Colors.primary : (index % 2 ? Colors.secondaryContainer : Colors.tertiaryContainer)
                }
            }
        }
        StageSpot {
            keys: ["dock"]
            cornerRadius: dockBox.radius
        }
    }

    // The island.
    Mark {
        id: island
        visible: screen.showIsland && screen.island
        width: Math.round(screen.width * 0.13)
        height: Math.round(screen.unit * 1.2)
        x: (screen.width - width) / 2
        y: {
            const barOnEdge = screen.panels.some(p => p.edge === screen.islandEdge);
            const inset = screen.frameWidth + (barOnEdge && screen.depths[screen.islandEdge] > 0 ? Math.max(0, (screen.depths[screen.islandEdge] - height) / 2) : Space.xs);
            return screen.islandEdge === "bottom" ? screen.height - height - inset : inset;
        }
        color: Colors.surfaceContainerLowest
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)

        Mark {
            anchors.centerIn: parent
            width: parent.width * 0.36
            height: Math.max(2, Math.round(screen.unit * 0.14))
            color: Qt.alpha(Colors.overBackground, 0.35)
        }
        StageSpot {
            keys: ["notch"]
            cornerRadius: island.radius
        }
    }

    // Rounded screen corners (theme.enableCorners): the shell's fillets.
    Mark {
        visible: screen.corners
        anchors.fill: parent
        anchors.margins: -Math.round(screen.unit * 0.5)
        radius: Math.round(screen.unit * 1.0)
        color: "transparent"
        border.width: Math.round(screen.unit * 0.5)
        border.color: Colors.background
    }

    // The page's own layer (surfaces opening somewhere).
    Item {
        id: overlayLayer
        anchors.fill: parent
    }
}
