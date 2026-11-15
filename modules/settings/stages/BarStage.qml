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

// Stage of the Bar page: the bar picked for editing, as wide as the page
// and at a readable scale. It is the shell's own panel (live/LiveBars: the
// real BarContent with every module of the registry, the real icons,
// workspace indicator, clock face and colours), laid out on a screen as
// wide as the page allows at up to its true size: the space between the
// groups shrinks, nothing else does. Not a shrunk desktop: where the bar
// sits is the Edge row's job. A click on a module scrolls to its card and
// flashes it (the clock to Clock, the workspaces to Workspaces, any other
// to On the bar); rows light up their part.
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

    // The screen the bar is laid out on: as wide as the stage at the
    // bar's true size, wider when its modules need more room (measured on
    // the real screen's width after every change of the bar), never wider
    // than the real screen.
    readonly property real pad: Space.m
    readonly property real maxZoom: 1
    property real need: 0
    // the width the bar is laid out for: follows the stage once its layout
    // settled (a page may size the stage from its height: no binding loop)
    property real laneWidth: 0
    onWidthChanged: Qt.callLater(() => stage.laneWidth = stage.width)
    Component.onCompleted: stage.laneWidth = stage.width
    // laid out on the real width while its natural length is measured
    property bool measuring: true
    readonly property real nativeW: stage.vertical ? Math.max(1, (stage.laneWidth - stage.pad * 2) / stage.maxZoom) : (stage.measuring ? LiveTarget.width : Math.min(LiveTarget.width, Math.max((stage.laneWidth - stage.pad * 2) / stage.maxZoom, stage.need)))
    readonly property real zoom: stage.nativeW > 0 ? Math.min(stage.maxZoom, (stage.laneWidth - stage.pad * 2) / stage.nativeW) : 1
    readonly property real barDepth: bars.depth(stage.currentEdge)
    readonly property real preferredHeight: stage.vertical ? Space.px(240) : Math.round(stage.barDepth * stage.zoom + stage.pad * 2)

    stageHeight: stage.preferredHeight

    // measure again after any change of the bar
    readonly property string signature: JSON.stringify([stage.panels[stage.current] || null, stage.laneWidth])
    onSignatureChanged: stage.remeasure()
    function remeasure() {
        stage.measuring = true;
        measure.restart();
    }
    Timer {
        id: measure
        interval: 150
        onTriggered: {
            const b = bars.bars[stage.current];
            const s = b ? b.styleItem : null;
            if (!s)
                return;
            // the groups at their natural length, and a gap between them
            stage.need = Math.ceil(s.startReach + s.endReach + s.centerReach * 2 + Space.xl * 4);
            stage.measuring = false;
            Qt.callLater(stage.refresh);
        }
    }

    // the modules, in stage px (after each layout)
    property var moduleRects: []
    function refresh() {
        // (torn down with the page: nothing to measure)
        if (typeof bars.modules !== "function")
            return;
        stage.moduleRects = bars.modules().map(m => {
            const p = m.item.mapToItem(bars, 0, 0);
            return {
                "id": m.id,
                "x": sandbox.x + p.x * stage.zoom,
                "y": sandbox.y + p.y * stage.zoom,
                "w": m.item.width * stage.zoom,
                "h": m.item.height * stage.zoom
            };
        });
    }
    onZoomChanged: Qt.callLater(stage.refresh)
    HoverHandler {
        onHoveredChanged: if (hovered)
            stage.refresh()
    }
    Connections {
        target: bars
        function onBarsChanged() {
            stage.remeasure();
        }
    }

    Item {
        id: crop
        anchors.fill: parent
        clip: true

        Item {
            id: sandbox
            width: stage.nativeW
            // a horizontal bar: its band; a vertical one: the top of it
            height: stage.vertical ? (crop.height - stage.pad) / stage.zoom : Math.max(stage.barDepth, 1)
            scale: stage.zoom
            transformOrigin: Item.TopLeft
            x: stage.pad
            y: stage.vertical ? stage.pad : (crop.height - height * stage.zoom) / 2

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
