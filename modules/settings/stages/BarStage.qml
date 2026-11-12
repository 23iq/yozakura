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

// Stage of the Bar page: your screen with your bar on it. Every panel is
// drawn by its style and edge (PanelSketch.js, the same geometry as the
// preset thumbnails) on the theme's own bar surface ("barbg"), with your
// modules in order; the clock is the real bar clock face (12-hour, date)
// and the workspaces show your count, numerals and the real active
// indicator. The island, the screen frame and two windows complete the
// picture. Any change of the bar briefly settles the bar in again; rows
// light up their part (StageSpot).
Stage {
    id: stage

    stageHeight: Space.px(250)

    function get(key, fallback) {
        const v = SettingsStore.get(key);
        return v === undefined || v === null ? fallback : SchemaUtil.plain(v);
    }

    // The bar config as bar.json holds it (legacy keys or bar.panels).
    readonly property var bar: ({
            "position": stage.get("bar.position", "top"),
            "layout": stage.get("bar.layout", {}),
            "panels": stage.get("bar.panels", []),
            "screenList": stage.get("bar.screenList", [])
        })
    readonly property var panels: PanelLayout.normalize(stage.bar).panels.filter(p => p && p.enabled !== false)
    readonly property bool compact: stage.get("bar.compact", false) === true
    readonly property bool frame: stage.get("bar.frameEnabled", false) === true
    readonly property bool showDate: stage.get("bar.clockShowDate", false) === true
    readonly property bool use12h: stage.get("bar.use12hFormat", false) === true
    readonly property string face: stage.get("bar.moduleOptions.clock.face", "digital")
    readonly property int workspaces: Math.max(1, Math.min(6, Number(stage.get("workspaces.shown", 5))))
    readonly property bool numbers: stage.get("workspaces.showNumbers", true) !== false
    readonly property string numerals: stage.get("workspaces.numeralStyle", WorkspaceNumerals.DEFAULT_ID)
    readonly property string indicator: stage.get("workspaces.indicatorStyle", IndicatorStyles.DEFAULT_ID)
    readonly property bool island: stage.get("notch.enabled", true) !== false

    // Module size in stage pixels: a bar of a 1920 px screen at the scale
    // of the stage, never so small that a glyph stops reading.
    readonly property real unit: Math.max(Space.px(16), Math.round(stage.width * 0.03)) * (stage.compact ? 0.86 : 1)
    readonly property real frameWidth: stage.frame ? Math.max(Space.xs, Math.round(stage.unit * 0.3)) : 0
    // Slots the wide modules take (the real clock and workspace strip).
    readonly property var spans: ({
            "clock": 2.3 + (stage.use12h ? 1.1 : 0) + (stage.showDate ? 2 : 0),
            "workspaces": stage.workspaces * 0.85 + 0.3
        })
    readonly property real innerWidth: stage.width - stage.frameWidth * 2
    readonly property real innerHeight: stage.height - stage.frameWidth * 2
    readonly property var sketches: stage.panels.map(p => PanelSketch.sketch(p, stage.innerWidth, stage.innerHeight, stage.unit, stage.spans))
    readonly property var depths: {
        const d = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        const n = Math.min(stage.panels.length, stage.sketches.length);
        for (let i = 0; i < n; i++)
            d[stage.panels[i].edge] = Math.max(d[stage.panels[i].edge], stage.sketches[i].depth);
        return d;
    }

    // A change of the bar settles it in again (a soft fade and lift).
    readonly property string signature: JSON.stringify([stage.panels, stage.compact, stage.spans])
    property real settle: 1
    onSignatureChanged: settleAnim.restart()
    NumberAnimation {
        id: settleAnim
        target: stage
        property: "settle"
        from: 0
        to: 1
        duration: Math.max(1, Motion.glide.duration)
        easing.type: Motion.glide.easing
    }

    // Two windows in the space the bar leaves.
    Item {
        id: windows
        readonly property real gap: Math.round(stage.unit * 0.5)
        x: stage.frameWidth + stage.depths.left + gap
        y: stage.frameWidth + stage.depths.top + gap
        width: stage.width - x - stage.frameWidth - stage.depths.right - gap
        height: stage.height - y - stage.frameWidth - stage.depths.bottom - gap
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
                            height: Math.max(2, Math.round(stage.unit * 0.18))
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
        visible: stage.frame
        radius: stage.radius
        color: "transparent"
        border.width: stage.frameWidth
        border.color: Colors.background

        StageSpot {
            keys: ["bar.frameEnabled", "bar.containBar"]
            cornerRadius: stage.radius
        }
    }

    // The bar (every panel).
    Item {
        id: barLayer
        x: stage.frameWidth
        y: stage.frameWidth
        width: stage.innerWidth
        height: stage.innerHeight
        opacity: 0.25 + 0.75 * stage.settle
        transform: Translate {
            y: (1 - stage.settle) * -Space.s
        }

        Repeater {
            model: stage.sketches
            delegate: Item {
                id: panel
                required property var modelData
                required property int index
                readonly property string edge: stage.panels[panel.index] ? stage.panels[panel.index].edge : "top"
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
                            backgroundOpacity: stage.barOpacity
                            enableShadow: false
                            radius: Math.min(parent.modelData.r, Styling.radius(0))
                        }
                        StageSpot {
                            keys: ["bar.layout", "bar.position", "bar.compact", "bar.panels", "bar.pinnedOnStartup", "bar.showPinButton", "bar.availableOnFullscreen", "bar.screenList"]
                            cornerRadius: shape.radius
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
                            spacing: Math.round(stage.unit * 0.3)
                            KitText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: stage.showDate && !panel.vertical
                                text: Qt.formatDate(new Date(2026, 3, 9), "ddd d")
                                color: Type.secondary
                                font.pixelSize: Math.round(stage.unit * 0.6)
                            }
                            Loader {
                                anchors.verticalCenter: parent.verticalCenter
                                active: slot.modelData.id === "clock"
                                source: Qt.resolvedUrl("../../bar/clock/ClockFace.qml")
                                onLoaded: {
                                    item.now = new Date(2026, 3, 9, 21, 47);
                                    item.textColor = Qt.binding(() => Colors.overBackground);
                                    item.fontSize = Qt.binding(() => Math.round(stage.unit * 0.66));
                                    item.face = Qt.binding(() => stage.face);
                                    item.use12h = Qt.binding(() => stage.use12h);
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
                            columns: panel.vertical ? 1 : stage.workspaces
                            readonly property real cell: Math.round(stage.unit * 0.85)
                            Repeater {
                                model: slot.modelData.id === "workspaces" ? stage.workspaces : 0
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
                                            const s = IndicatorStyles.get(stage.indicator);
                                            return s && !s.strip ? Qt.resolvedUrl("../../bar/workspaces/indicators/" + s.component) : Qt.resolvedUrl("../../bar/workspaces/indicators/PillIndicator.qml");
                                        }
                                        onLoaded: item.indicator = fake
                                    }
                                    KitText {
                                        anchors.centerIn: parent
                                        visible: stage.numbers
                                        text: WorkspaceNumerals.format(stage.numerals, ws.index + 1)
                                        font.pixelSize: Math.round(stage.unit * 0.5)
                                        font.weight: Font.DemiBold
                                        color: ws.current ? Colors.primary : Qt.alpha(Colors.overBackground, ws.index < 3 ? 0.9 : 0.45)
                                    }
                                    Mark {
                                        anchors.centerIn: parent
                                        visible: !stage.numbers && !ws.current
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

    // The island at the top of the screen.
    Mark {
        visible: stage.island
        width: Math.round(stage.width * 0.13)
        height: Math.round(stage.unit * 1.2)
        x: (stage.width - width) / 2
        y: stage.frameWidth + (stage.depths.top > 0 && stage.panels.some(p => p.edge === "top") ? Math.max(0, (stage.depths.top - height) / 2) : Space.xs)
        color: Colors.surfaceContainerLowest
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)

        Mark {
            anchors.centerIn: parent
            width: parent.width * 0.36
            height: Math.max(2, Math.round(stage.unit * 0.14))
            color: Qt.alpha(Colors.overBackground, 0.35)
        }
    }
}
