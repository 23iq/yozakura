pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "DockLook.js" as DockLook

// The dock's look in one card of the page row: its size as small docks of
// growing icons (dock.iconSize, the nearest step ringed) over the running
// indicator drawn under an app (none / dot / line / glow / brush:
// dock.showRunningIndicators + dock.indicator). A click is one change; the
// stage's dock follows.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property int iconSize: Number(SettingsStore.get("dock.iconSize") ?? 24)
    readonly property int sizeIndex: DockLook.nearestSize(root.iconSize)
    readonly property string indicator: DockLook.indicatorOf(SettingsStore.get("dock.showRunningIndicators"), SettingsStore.get("dock.indicator"))
    readonly property real half: (root.implicitHeight - Space.m) / 2

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3

    function pickIndicator(id) {
        SettingsStore.transaction("prefs.dock.indicator", () => {
            const w = DockLook.indicatorWrites(id);
            Object.keys(w).forEach(k => SettingsStore.set(k, w[k]));
        });
    }

    // A tile: a picture over its name, the chosen one ringed.
    component Tile: Mark {
        id: t
        property bool chosen: false
        property string label: ""
        readonly property real pictureHeight: t.height - name.implicitHeight - Space.s
        default property alias picture: pic.data
        signal picked

        radius: Look.radius("box", height)
        color: Look.raisedFill(hit.containsMouse)
        border.width: t.chosen ? Space.stroke - 1 : Space.hairline
        border.color: t.chosen ? Type.accent : Type.hairline
        Accessible.role: Accessible.RadioButton
        Accessible.name: t.label
        Accessible.checked: t.chosen

        Item {
            id: pic
            width: parent.width
            height: t.pictureHeight
        }
        KitText {
            id: name
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Space.xs
            width: Math.min(implicitWidth, parent.width - Space.xs * 2)
            role: "caption"
            elide: Text.ElideRight
            font.weight: t.chosen ? Look.activeLabelWeight : Look.labelWeight
            color: t.chosen ? Type.text : Type.secondary
            text: t.label
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.picked()
        }
    }

    // sizes: a small dock per step, its icons at their relative size
    Row {
        id: sizes
        width: parent.width
        height: root.half
        spacing: Space.s
        Repeater {
            model: DockLook.SIZES
            delegate: Tile {
                id: tile
                required property var modelData
                required property int index
                objectName: "dockSize:" + modelData.px
                width: (sizes.width - sizes.spacing * (DockLook.SIZES.length - 1)) / DockLook.SIZES.length
                height: sizes.height
                chosen: tile.index === root.sizeIndex
                label: I18n.t(modelData.label)
                onPicked: SettingsStore.set("dock.iconSize", tile.modelData.px)

                Mark {
                    id: dockBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((tile.pictureHeight - height) / 2)
                    readonly property real icon: Math.round(tile.pictureHeight * 0.5 * tile.modelData.px / DockLook.SIZES[DockLook.SIZES.length - 1].px)
                    width: icon * 3 + Space.xs * 4
                    height: icon + Space.xs * 2
                    radius: Look.radius("small", height)
                    color: tile.chosen ? Qt.alpha(Type.accent, 0.85) : Colors.surfaceContainerHighest
                    Row {
                        anchors.centerIn: parent
                        spacing: Space.xs
                        Repeater {
                            model: 3
                            delegate: Mark {
                                width: dockBar.icon
                                height: dockBar.icon
                                radius: Look.radius("small", height)
                                color: tile.chosen ? Colors.overPrimary : Type.secondary
                            }
                        }
                    }
                }
            }
        }
    }

    // the running indicator under an app
    Row {
        id: marks
        y: sizes.height + Space.m
        width: parent.width
        height: root.half
        spacing: Space.s
        Repeater {
            model: DockLook.INDICATORS
            delegate: Tile {
                id: ind
                required property var modelData
                objectName: "dockIndicator:" + modelData.id
                width: (marks.width - marks.spacing * (DockLook.INDICATORS.length - 1)) / DockLook.INDICATORS.length
                height: marks.height
                chosen: ind.modelData.id === root.indicator
                label: I18n.t(modelData.label)
                onPicked: root.pickIndicator(ind.modelData.id)

                Item {
                    id: app
                    readonly property real s: Math.round(ind.pictureHeight * 0.46)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((ind.pictureHeight - s - Space.s) / 2)
                    width: s
                    height: s + Space.s
                    // the glow sits behind the app
                    Mark {
                        visible: ind.modelData.id === "glow"
                        anchors.centerIn: appIcon
                        width: appIcon.width * 1.5
                        height: width
                        color: Qt.alpha(Type.accent, 0.35)
                    }
                    Mark {
                        id: appIcon
                        width: app.s
                        height: app.s
                        radius: Look.radius("small", height)
                        color: Colors.surfaceContainerHighest
                    }
                    Mark {
                        visible: ind.modelData.id === "dot" || ind.modelData.id === "line" || ind.modelData.id === "brush"
                        anchors.horizontalCenter: appIcon.horizontalCenter
                        y: appIcon.height + Space.xs
                        width: ind.modelData.id === "dot" ? Space.xs + 1 : (ind.modelData.id === "line" ? app.s * 0.6 : app.s * 0.9)
                        height: ind.modelData.id === "brush" ? Space.xs : Space.xs - 1
                        radius: ind.modelData.id === "brush" ? Space.xs / 4 : height / 2
                        rotation: ind.modelData.id === "brush" ? -4 : 0
                        color: Type.accent
                    }
                }
            }
        }
    }
}
