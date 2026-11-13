pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/dashboard/DashboardTabs.js" as DashboardTabs

// Stage of Dashboard: the dashboard itself on a plain ground, at a
// readable scale. Its tab rail shows the visible tabs in their order; a
// click on a tab shows it here (Widgets: the home view as configured, the
// stage with its tinted player and metrics strip, the composed overview or
// the widget grid from layout.dashboard.grid; Wallpapers: your library;
// Metrics: live-looking graphs). Where it opens is the Opens in row.
Stage {
    id: stage
    objectName: "dashboardStage"

    readonly property var tabs: DashboardTabs.resolve(SettingsStore.get("layout.dashboard.tabs")).filter(t => t.visible)
    // the tab shown on the stage (falls back to the first visible one)
    property string shown: ""
    readonly property string current: stage.tabs.some(t => t.id === stage.shown) ? stage.shown : (stage.tabs.length > 0 ? stage.tabs[0].id : "widgets")
    readonly property string home: String(SettingsStore.get("layout.dashboard.home") || "stage")
    readonly property bool tint: SettingsStore.get("layout.dashboard.heroTint") !== false
    readonly property bool metrics: SettingsStore.get("layout.dashboard.showMetrics") !== false
    readonly property var grid: SettingsStore.get("layout.dashboard.grid") || ({})
    readonly property var walls: GlobalStates.wallpaperManager ? (GlobalStates.wallpaperManager.wallpaperPaths || []) : []
    readonly property var widgetIcons: ({
            "player": "player",
            "quickControls": "faders",
            "calendar": "calendar",
            "notifications": "bell",
            "levels": "chartBar",
            "weather": "cloudSun",
            "clock": "clock",
            "notes": "note"
        })

    // the dashboard's unit at this stage's scale
    readonly property real u: Space.px(26)
    // a strip as wide as the page (SettingsPage)
    readonly property bool strip: true
    readonly property real preferredHeight: Space.px(250)

    stageHeight: stage.preferredHeight

    StyledRect {
        id: dash
        objectName: "dashboardMini"
        readonly property real u: stage.u
        readonly property real pad: Math.round(u * 0.5)
        anchors.centerIn: parent
        width: Math.round(Math.min(stage.width * 0.8, stage.u * 34))
        height: stage.height - Space.m * 2
        variant: "popup"
        enableShadow: true
        radius: Look.radius("box", Space.controlL)

        // the tab rail
        Row {
            id: rail
            objectName: "dashboardRail"
            x: dash.pad
            y: dash.pad
            spacing: Space.xs
            Repeater {
                model: stage.tabs
                delegate: Chip {
                    id: tabChip
                    required property var modelData
                    readonly property var meta: DashboardTabs.tabs[DashboardTabs.indexOf(modelData.id)] || {}
                    objectName: "dashboardTab:" + modelData.id
                    dense: true
                    quiet: true
                    // a narrow dashboard (a sheet) shows the icons only
                    showLabel: dash.width > Space.px(380)
                    active: stage.current === modelData.id
                    icon: Icons[tabChip.meta.icon] ?? ""
                    text: I18n.t(tabChip.meta.labelKey || "")
                    onClicked: stage.shown = tabChip.modelData.id
                }
            }
        }
        StageSpot {
            anchors.fill: rail
            keys: ["layout.dashboard.tabs"]
        }

        Item {
            id: body
            x: dash.pad
            y: rail.y + rail.height + dash.pad
            width: dash.width - dash.pad * 2
            height: dash.height - y - dash.pad
            clip: true
            readonly property real gap: Math.round(dash.u * 0.3)

            // Widgets: the stage home (player, next up, the week, metrics)
            Item {
                anchors.fill: parent
                visible: stage.current === "widgets" && stage.home === "stage"
                readonly property real strip: stage.metrics ? Math.round(dash.u * 1.1) : 0
                Box {
                    id: hero
                    objectName: "dashboardHero"
                    width: parent.width * 0.58
                    height: parent.height - parent.strip - (parent.strip > 0 ? body.gap : 0)
                    tinted: stage.tint
                    player: true
                    lines: 0
                    StageSpot {
                        keys: ["layout.dashboard.heroTint", "layout.dashboard.home"]
                    }
                }
                Column {
                    x: hero.width + body.gap
                    width: parent.width - x
                    spacing: body.gap
                    Box {
                        width: parent.width
                        height: (hero.height - body.gap) / 2
                        icon: "calendar"
                        lines: 2
                    }
                    Box {
                        width: parent.width
                        height: (hero.height - body.gap) / 2
                        icon: "bell"
                        lines: 1
                    }
                }
                StageSpot {
                    anchors.fill: metricsStrip
                    visible: metricsStrip.visible && opacity > 0
                    keys: ["layout.dashboard.showMetrics"]
                }
                Row {
                    id: metricsStrip
                    objectName: "dashboardMetricsStrip"
                    visible: parent.strip > 0
                    y: parent.height - parent.strip
                    width: parent.width
                    height: parent.strip
                    spacing: body.gap
                    Repeater {
                        model: ["cpu", "ram", "gpu", "wifiHigh"]
                        delegate: Box {
                            required property string modelData
                            width: (body.width - body.gap * 3) / 4
                            height: parent.height
                            icon: modelData
                            lines: 0
                            graph: true
                        }
                    }
                }
            }

            // Widgets: the composed overview (two fixed columns)
            Item {
                anchors.fill: parent
                visible: stage.current === "widgets" && stage.home === "composed"
                Repeater {
                    model: [[0, 0, 0.5, 0.36, "clock"], [0, 0.36, 0.5, 0.64, "musicNotes"], [0.5, 0, 0.5, 0.3, "faders"], [0.5, 0.3, 0.5, 0.4, "calendar"], [0.5, 0.7, 0.5, 0.3, "bell"]]
                    delegate: Box {
                        required property var modelData
                        x: modelData[0] * body.width + (modelData[0] > 0 ? body.gap / 2 : 0)
                        y: modelData[1] * body.height + (modelData[1] > 0 ? body.gap / 2 : 0)
                        width: modelData[2] * body.width - body.gap / 2
                        height: modelData[3] * body.height - (modelData[1] > 0 && modelData[1] + modelData[3] < 1 ? body.gap : body.gap / 2)
                        icon: modelData[4]
                        lines: 1
                    }
                }
            }

            // Widgets: the editable grid (layout.dashboard.grid)
            Item {
                id: bento
                anchors.fill: parent
                visible: stage.current === "widgets" && stage.home === "bento"
                readonly property int cols: Math.max(1, Number(stage.grid.cols) || 4)
                readonly property var cells: stage.grid.cells || []
                readonly property int rows: Math.max(1, bento.cells.reduce((m, c) => Math.max(m, (c.y || 0) + (c.h || 1)), 1))
                Repeater {
                    model: bento.cells
                    delegate: Box {
                        required property var modelData
                        x: (modelData.x || 0) * body.width / bento.cols + body.gap / 2
                        y: (modelData.y || 0) * body.height / bento.rows + body.gap / 2
                        width: (modelData.w || 1) * body.width / bento.cols - body.gap
                        height: (modelData.h || 1) * body.height / bento.rows - body.gap
                        icon: stage.widgetIcons[modelData.widget] || "squaresFour"
                        lines: 1
                    }
                }
            }

            // Wallpapers: the library
            Grid {
                visible: stage.current === "wallpapers"
                columns: 4
                spacing: body.gap
                Repeater {
                    model: stage.current === "wallpapers" ? stage.walls.slice(0, 12) : []
                    delegate: Art {
                        required property string modelData
                        width: (body.width - body.gap * 3) / 4
                        height: width * 9 / 16
                        radius: Look.radius("small", height)
                        source: "file://" + modelData
                    }
                }
            }

            // Metrics: graphs
            Grid {
                visible: stage.current === "metrics"
                columns: 2
                spacing: body.gap
                Repeater {
                    model: ["cpu", "ram", "gpu", "wifiHigh"]
                    delegate: Box {
                        required property string modelData
                        width: (body.width - body.gap) / 2
                        height: (body.height - body.gap) / 2
                        icon: modelData
                        lines: 0
                        graph: true
                    }
                }
            }
        }
    }

    // A widget: a raised box with its icon, a few text lines or a graph;
    // `tinted`: the player coloured by the art.
    component Box: Mark {
        id: box
        property string icon: ""
        property int lines: 1
        property bool tinted: false
        property bool graph: false
        property bool player: false
        readonly property real u: stage.u
        radius: Look.radius("small", Math.min(width, height))
        color: box.tinted ? Qt.alpha(Colors.primary, 0.32) : Look.raisedFill(false)
        border.width: Space.hairline
        border.color: Type.hairline

        Icon {
            x: Math.round(box.u * 0.35)
            y: box.graph ? (box.height - height) / 2 : Math.round(box.u * 0.3)
            icon: Icons[box.icon] ?? ""
            role: "secondary"
            tone: box.tinted ? "accent" : "secondary"
        }
        Column {
            x: Math.round(box.u * 0.35)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(box.u * 0.35)
            spacing: Math.round(box.u * 0.18)
            Repeater {
                model: box.lines
                delegate: Mark {
                    required property int index
                    width: box.width * (index === 0 ? 0.5 : 0.32)
                    height: Math.max(2, Math.round(box.u * 0.18))
                    color: Qt.alpha(Type.text, index === 0 ? 0.6 : 0.3)
                }
            }
        }
        // the player: the art, the title and the timeline
        Mark {
            id: art
            visible: box.player
            x: Math.round(box.u * 0.6)
            y: Math.round(box.u * 1.4)
            width: Math.min(box.height * 0.5, box.width * 0.4)
            height: width
            radius: Look.radius("small", height)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Colors.primary, 1.15)
                }
                GradientStop {
                    position: 1
                    color: Colors.tertiary
                }
            }
            Icon {
                anchors.centerIn: parent
                icon: Icons.musicNotes
                size: Math.round(parent.height * 0.4)
                color: Colors.overPrimary
            }
        }
        Row {
            visible: box.player
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: timeline.top
            anchors.bottomMargin: Math.round(box.u * 0.3)
            spacing: Math.round(box.u * 0.6)
            Repeater {
                model: ["previous", "play", "next"]
                delegate: Icon {
                    required property string modelData
                    icon: Icons[modelData] ?? ""
                    role: "secondary"
                    tone: modelData === "play" ? "accent" : "secondary"
                }
            }
        }
        ProgressLine {
            id: timeline
            visible: box.player
            x: Math.round(box.u * 0.6)
            width: box.width - x * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(box.u * 0.5)
            value: 0.42
        }
        Sparkline {
            visible: box.graph
            x: Math.round(box.u * 1.3)
            width: box.width - x - Math.round(box.u * 0.3)
            height: box.height * 0.6
            anchors.verticalCenter: parent.verticalCenter
            values: [0.3, 0.42, 0.36, 0.55, 0.48, 0.62, 0.5, 0.58, 0.44, 0.52]
        }
    }
}
