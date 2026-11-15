pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store
import qs.modules.settings.thumbs
import qs.modules.settings.live
import "DockLook.js" as DockLook

// The dock's look in one card: its size as your real dock at each step
// (dock.iconSize, the nearest step chosen; live/LiveDock with the size as
// an override, one scale for all) over the running indicator under one of
// your running apps (none / dot / line / glow / brush:
// dock.showRunningIndicators + dock.indicator, the dock's own indicator). Two picture grids of the
// window's one pattern (ChoiceGrid: the name under the picture, the chosen
// one ringed with a check badge). A click is one change; the stage's dock
// follows.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property int iconSize: Number(SettingsStore.get("dock.iconSize") ?? 24)
    readonly property int sizeIndex: DockLook.nearestSize(root.iconSize)
    readonly property string indicator: DockLook.indicatorOf(SettingsStore.get("dock.showRunningIndicators"), SettingsStore.get("dock.indicator"))
    // the pictures are taken again when the dock or the colours change
    readonly property string look: JSON.stringify([root.iconSize, root.indicator, SettingsStore.get("dock.theme"), SettingsStore.get("dock.height"), SettingsStore.get("dock.spacing"), SettingsStore.get("dock.position"), String(Colors.primary), String(Colors.background)])
    // in a card of fixed height: both grids share it, their pictures as
    // tall as the names under them leave
    readonly property real captionHeight: Math.ceil(Type.size("secondary") * 1.5) + Space.s
    readonly property real pictureHeight: root.fillHeight > 0 ? Math.max(Space.px(36), (root.fillHeight - Space.m) / 2 - root.captionHeight) : -1

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : sizes.implicitHeight + Space.m + marks.implicitHeight

    function pickIndicator(id) {
        SettingsStore.transaction("prefs.dock.indicator", () => {
            const w = DockLook.indicatorWrites(id);
            Object.keys(w).forEach(k => SettingsStore.set(k, w[k]));
        });
    }

    // sizes: a small dock per step, its icons at their relative size
    ChoiceGrid {
        id: sizes
        objectName: "dockSizes"
        width: parent.width
        options: DockLook.SIZES.map(s => ({
                    "value": s.px,
                    "label": s.label
                }))
        value: DockLook.SIZES[root.sizeIndex].px
        aspect: 0.5
        previewHeight: root.pictureHeight
        // your real dock at each size, all at one scale (the largest
        // fits the picture's height), so the steps compare; a long dock
        // is cut by the picture
        picture: Component {
            ThumbGround {
                id: size
                property var option: null
                anchors.fill: parent
                LiveDock {
                    anchors.fill: parent
                    active: !!size.option
                    snapshot: true
                    refreshKey: root.look
                    zoom: size.height * 0.62 / (DockLook.SIZES[DockLook.SIZES.length - 1].px + Space.controlM)
                    margin: 0
                    overrides: ({
                            "dock.iconSize": size.option ? size.option.value : 24
                        })
                }
            }
        }
        onSelected: v => SettingsStore.set("dock.iconSize", v)
    }

    // the running indicator under an app
    ChoiceGrid {
        id: marks
        objectName: "dockIndicators"
        y: sizes.height + Space.m
        width: parent.width
        options: DockLook.INDICATORS.map(i => ({
                    "value": i.id,
                    "label": i.label
                }))
        value: root.indicator
        aspect: 0.5
        previewHeight: root.pictureHeight
        // your real dock, framed on a running app, with the indicator
        picture: Component {
            ThumbGround {
                id: ind
                property var option: null
                anchors.fill: parent
                LiveDock {
                    anchors.fill: parent
                    anchors.margins: Space.xs
                    active: !!ind.option
                    snapshot: true
                    refreshKey: root.look
                    frame: "app"
                    maxZoom: 2
                    overrides: ind.option ? DockLook.indicatorWrites(ind.option.value) : ({})
                }
            }
        }
        onSelected: v => root.pickIndicator(v)
    }
}
