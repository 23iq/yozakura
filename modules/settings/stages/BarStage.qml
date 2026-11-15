pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "../PanelsModel.js" as PanelsModel
import "../SchemaUtil.js" as SchemaUtil
import "../live/LiveKeys.js" as LiveKeys
import "BarWindows.js" as BarWindows

// Stage of the Bar page: the bar picked for editing, as wide as the page
// and at a readable scale. It is the shell's own panel (live/LiveBars: the
// real BarContent with every module of the registry, the real icons,
// workspace indicator, clock face and colours), laid out on a screen as
// wide as the page allows at up to its true size: the space between the
// groups shrinks, nothing else does. A vertical bar stands at its true size
// on a screen as tall as yours, shown as windows side by side: its top end,
// its middle (when something sits there) and its bottom end. Not a shrunk
// desktop: where the bar sits is the Edge row's job. A click on a module
// scrolls to its card and flashes it (the clock to Clock, the workspaces to
// Workspaces, any other to On the bar); rows light up their part.
Stage {
    id: stage
    objectName: "barStage"

    readonly property var barConfig: ({
            "position": SchemaUtil.plain(SettingsStore.get("bar.position")) || "top",
            "layout": SchemaUtil.plain(SettingsStore.get("bar.layout")) || {},
            "panels": SchemaUtil.plain(SettingsStore.get("bar.panels")) || []
        })
    readonly property var panels: PanelsModel.panelsOf(stage.barConfig)
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, stage.panels.length - 1))
    readonly property string currentEdge: stage.panels[stage.current] ? stage.panels[stage.current].edge : "top"
    readonly property bool vertical: stage.currentEdge === "left" || stage.currentEdge === "right"
    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true

    readonly property real pad: Space.m
    readonly property real maxZoom: 1
    // the width the bar is laid out for: follows the stage once its layout
    // settled (a page may size the stage from its height: no binding loop)
    property real laneWidth: 0
    onWidthChanged: Qt.callLater(() => stage.laneWidth = stage.width)
    Component.onCompleted: stage.laneWidth = stage.width

    // A horizontal bar: the screen it is laid out on, as wide as the stage
    // at the bar's true size, wider when its groups need more room (their
    // natural length, read from a copy laid out on the real width: the bar
    // shown never changes scale to be measured), never wider than the real
    // screen.
    // (kept while the copy is built again after a change)
    readonly property real measured: {
        const b = measureBars.bars[stage.current];
        const s = b ? b.styleItem : null;
        return s && s.startReach + s.endReach + s.centerReach > 0 ? Math.ceil(s.startReach + s.endReach + s.centerReach * 2 + Space.xl * 4) : 0;
    }
    property real need: 0
    onMeasuredChanged: {
        if (stage.measured <= 0)
            return;
        stage.need = stage.measured;
        measureRest.restart();
    }
    // The copy lives while the bar changes (a slider drag re-lays it out,
    // never rebuilds it) and goes once its measure held still a moment: an
    // idle Bar tab keeps one live bar, not two. A change builds it again.
    property bool measuring: true
    Timer {
        id: measureRest
        interval: 2000
        onTriggered: stage.measuring = false
    }
    // A vertical bar: a screen as tall as yours, the bar's band and a
    // little of the screen beside it
    readonly property real sideRoom: Space.px(36)
    readonly property real nativeW: stage.vertical ? stage.barDepth + stage.sideRoom * 2 : Math.min(LiveTarget.width, Math.max((stage.laneWidth - stage.pad * 2) / stage.maxZoom, stage.need))
    readonly property real nativeH: stage.vertical ? LiveTarget.height : Math.max(stage.barDepth, 1)
    readonly property real zoom: stage.vertical ? stage.maxZoom : (stage.nativeW > 0 ? Math.min(stage.maxZoom, (stage.laneWidth - stage.pad * 2) / stage.nativeW) : 1)
    readonly property real barDepth: bars.depth(stage.currentEdge)
    readonly property real preferredHeight: stage.vertical ? Space.px(260) : Math.round(stage.barDepth * stage.zoom + stage.pad * 2)

    stageHeight: stage.preferredHeight

    // A vertical bar's windows ([{y, len}] native, along the bar: set by
    // refresh, from where its modules are) and where each stands in the
    // stage ([{x, y, w, h}])
    property var windows: []
    readonly property var windowRects: BarWindows.place(stage.windows, stage.width, stage.height, stage.nativeW * stage.zoom, stage.zoom, Space.xl)

    // the modules, in stage px (after each layout)
    property var moduleRects: []
    function refresh() {
        // (torn down with the page: nothing to measure)
        if (typeof bars.modules !== "function")
            return;
        const mods = bars.modules().map(m => {
            const p = m.item.mapToItem(bars, 0, 0);
            return {
                "id": m.id,
                "x": p.x,
                "y": p.y,
                "w": m.item.width,
                "h": m.item.height
            };
        });
        const spans = stage.vertical ? BarWindows.windows(stage.nativeH, Math.max(1, (stage.height - stage.pad * 2) / stage.zoom), mods) : [];
        if (JSON.stringify(spans) !== JSON.stringify(stage.windows))
            stage.windows = spans;
        stage.moduleRects = stage.vertical ? BarWindows.mapModules(mods, stage.windows, stage.windowRects, stage.zoom) : mods.map(m => ({
                    "id": m.id,
                    "x": sandbox.x + m.x * stage.zoom,
                    "y": sandbox.y + m.y * stage.zoom,
                    "w": m.w * stage.zoom,
                    "h": m.h * stage.zoom
                }));
    }
    // measured again once a change has laid out
    readonly property string signature: JSON.stringify([stage.panels[stage.current] || null, stage.laneWidth, stage.height])
    onSignatureChanged: {
        relayout.restart();
        stage.measuring = true;
        measureRest.restart();
    }
    onZoomChanged: relayout.restart()
    onNeedChanged: relayout.restart()
    Timer {
        id: relayout
        interval: 150
        onTriggered: stage.refresh()
    }
    HoverHandler {
        onHoveredChanged: if (hovered)
            stage.refresh()
    }
    Connections {
        target: bars
        function onBarsChanged() {
            relayout.restart();
        }
    }

    // the copy a horizontal bar is measured on (never drawn)
    LiveBars {
        id: measureBars
        objectName: "barStageMeasure"
        width: LiveTarget.width
        height: Math.max(stage.barDepth, 1)
        opacity: 0
        visible: !stage.vertical
        active: !stage.vertical && stage.measuring
        screen: LiveTarget.screen
        only: stage.current
        enabled: false
    }

    Item {
        id: crop
        anchors.fill: parent
        clip: true

        Item {
            id: sandbox
            width: stage.nativeW
            height: stage.nativeH
            scale: stage.zoom
            transformOrigin: Item.TopLeft
            x: stage.vertical ? 0 : stage.pad
            y: stage.vertical ? 0 : (crop.height - height * stage.zoom) / 2

            LiveBars {
                id: bars
                objectName: "barStageLive"
                anchors.fill: parent
                screen: LiveTarget.screen
                only: stage.current
                // the real panel, as a picture: no input of its own
                enabled: false
            }
        }

        // a vertical bar: its windows, side by side (the bar itself is
        // drawn only through them)
        Repeater {
            model: stage.vertical ? stage.windowRects : []
            delegate: Item {
                id: win
                required property var modelData
                required property int index
                readonly property var span: stage.windows[win.index] || ({
                        "y": 0,
                        "len": 0
                    })
                x: win.modelData.x
                y: win.modelData.y
                width: win.modelData.w
                height: win.modelData.h

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: sandbox
                    hideSource: true
                    live: true
                    sourceRect: Qt.rect(0, win.span.y, stage.nativeW, win.span.len)
                    textureSize: Qt.size(Math.max(1, Math.ceil(win.width * 2)), Math.max(1, Math.ceil(win.height * 2)))
                    smooth: true
                }
                // the window's edge: a piece of the screen, cut where the
                // bar goes on
                Mark {
                    anchors.fill: parent
                    radius: Look.radius("small", win.height)
                    color: "transparent"
                    border.width: Space.hairline
                    border.color: Type.hairline
                }
            }
        }

        // every module: its spot, and a button to its card
        Repeater {
            model: stage.moduleRects
            delegate: Item {
                id: part
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h

                StageSpot {
                    keys: LiveKeys.moduleKeys(part.modelData.id)
                }
                MouseArea {
                    id: area
                    objectName: "barModule:" + part.modelData.id
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsStore.navigate("bar", LiveKeys.sectionOf(part.modelData.id), "")

                    Mark {
                        anchors.fill: parent
                        radius: Space.smallRadius
                        color: Qt.alpha(Type.accent, 0.18)
                        opacity: area.containsMouse ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            enabled: Motion.micro.duration > 0
                            NumberAnimation {
                                duration: Motion.micro.duration
                                easing.type: Motion.micro.easing
                            }
                        }
                    }
                }
            }
        }
    }
}
