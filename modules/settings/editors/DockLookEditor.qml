pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store
import qs.modules.settings.thumbs
import "DockLook.js" as DockLook

// The dock's look in one card: its size as small docks of growing icons
// (dock.iconSize, the nearest step chosen) over the running indicator
// drawn under an app (none / dot / line / glow / brush:
// dock.showRunningIndicators + dock.indicator). Two picture grids of the
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
        picture: Component {
            ThumbGround {
                id: size
                property var option: null
                // to scale with the largest size, which fits the picture
                // both ways (a narrow card never draws past it)
                readonly property real icon: size.option ? Math.round(Math.min(size.height * 0.42, (size.width - Space.xs * 8) / 3) * size.option.value / DockLook.SIZES[DockLook.SIZES.length - 1].px) : 0
                anchors.fill: parent
                Mark {
                    anchors.centerIn: parent
                    width: size.icon * 3 + Space.xs * 4
                    height: size.icon + Space.xs * 2
                    radius: Look.radius("small", height)
                    color: Colors.surfaceContainerHighest
                    Row {
                        anchors.centerIn: parent
                        spacing: Space.xs
                        Repeater {
                            model: 3
                            delegate: Mark {
                                width: size.icon
                                height: size.icon
                                radius: Look.radius("small", height)
                                color: Type.secondary
                            }
                        }
                    }
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
        picture: Component {
            ThumbGround {
                id: ind
                property var option: null
                readonly property string kind: ind.option ? ind.option.value : ""
                readonly property real s: Math.round(Math.min(ind.height, ind.width) * 0.4)
                anchors.fill: parent
                Item {
                    id: app
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((ind.height - height) / 2)
                    width: ind.s
                    height: ind.s + Space.s
                    // the glow sits behind the app
                    Mark {
                        visible: ind.kind === "glow"
                        anchors.centerIn: appIcon
                        width: appIcon.width * 1.5
                        height: width
                        color: Qt.alpha(Type.accent, 0.35)
                    }
                    Mark {
                        id: appIcon
                        width: ind.s
                        height: ind.s
                        radius: Look.radius("small", height)
                        color: Colors.surfaceContainerHighest
                    }
                    Mark {
                        visible: ind.kind === "dot" || ind.kind === "line" || ind.kind === "brush"
                        anchors.horizontalCenter: appIcon.horizontalCenter
                        y: appIcon.height + Space.xs
                        width: ind.kind === "dot" ? Space.xs + 1 : (ind.kind === "line" ? ind.s * 0.6 : ind.s * 0.9)
                        height: ind.kind === "brush" ? Space.xs : Space.xs - 1
                        radius: ind.kind === "brush" ? Space.xs / 4 : height / 2
                        rotation: ind.kind === "brush" ? -4 : 0
                        color: Type.accent
                    }
                }
            }
        }
        onSelected: v => root.pickIndicator(v)
    }
}
