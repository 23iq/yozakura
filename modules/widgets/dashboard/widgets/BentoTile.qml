pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// One bento tile: loads a registry widget (WidgetRegistry.js) and, in edit
// mode, lets it be dragged (whole tile), resized (bottom-right handle) and
// removed (x). It only reports pointer offsets; BentoView owns the grid.
Item {
    id: tile

    required property var entry
    required property var cell
    property real cellW: Metrics.bentoCell
    property real cellH: Metrics.bentoCell
    property real gap: Metrics.spacing
    property bool editing: false
    property bool present: true
    property bool selected: false

    signal dragMoved(real px, real py)
    signal dragEnded
    signal resizeMoved(real pw, real ph)
    signal resizeEnded
    signal removeRequested
    signal pressed

    readonly property bool dragging: moveDrag.active
    readonly property bool resizing: sizeDrag.active
    readonly property real gridX: cell.x * (cellW + gap)
    readonly property real gridY: cell.y * (cellH + gap)
    readonly property real gridW: cell.w * cellW + (cell.w - 1) * gap
    readonly property real gridH: cell.h * cellH + (cell.h - 1) * gap
    readonly property alias item: content.item

    objectName: "bentoTile_" + (entry ? entry.id : "")
    visible: present
    x: dragging ? gridX + moveDrag.activeTranslation.x : gridX
    y: dragging ? gridY + moveDrag.activeTranslation.y : gridY
    width: resizing ? Math.max(cellW, gridW + sizeDrag.activeTranslation.x) : gridW
    height: resizing ? Math.max(cellH, gridH + sizeDrag.activeTranslation.y) : gridH
    z: dragging || resizing ? 10 : (selected ? 2 : 1)
    scale: dragging ? 1.03 : 1

    Accessible.role: Accessible.Grouping
    Accessible.name: entry ? I18n.t(entry.labelKey) : ""

    Behavior on x {
        enabled: !tile.dragging && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on y {
        enabled: !tile.dragging && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on width {
        enabled: !tile.resizing && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on height {
        enabled: !tile.resizing && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on scale {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    // Entering edit mode: one subtle pulse, not a loop.
    function pulse() {
        if (Motion.emphasis.duration > 0)
            pulseAnim.restart();
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation {
            target: content
            property: "scale"
            to: 0.97
            duration: Motion.emphasis.duration / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: content
            property: "scale"
            to: 1
            duration: Motion.emphasis.duration / 2
            easing.type: Motion.emphasis.easing
        }
    }

    Loader {
        id: content
        anchors.fill: parent
        enabled: !tile.editing
        active: tile.present
        source: tile.entry ? Qt.resolvedUrl(tile.entry.url) : ""
        opacity: tile.editing ? 0.85 : 1
        onLoaded: {
            // Optional host-agnostic inputs of a bento widget.
            const it = content.item;
            const inputs = {
                "cellW": () => tile.cellW,
                "cellH": () => tile.cellH,
                "compact": () => tile.cell.w === 1 || tile.cell.h === 1
            };
            for (const k in inputs)
                if (it[k] !== undefined)
                    it[k] = Qt.binding(inputs[k]);
        }

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
            }
        }
    }

    // Edit chrome
    StyledRect {
        id: chrome
        anchors.fill: parent
        variant: tile.selected || tile.dragging ? "primary" : "focus"
        backgroundOpacity: tile.dragging ? 0.18 : 0.08
        radius: Styling.radius(4)
        visible: opacity > 0
        opacity: tile.editing ? 1 : 0

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: tile.editing ? Motion.enter.duration : Motion.exit.duration
                easing.type: tile.editing ? Motion.enter.easing : Motion.exit.easing
            }
        }

        HoverHandler {
            enabled: tile.editing
            cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        TapHandler {
            enabled: tile.editing
            onPressedChanged: if (pressed)
                tile.pressed()
        }

        DragHandler {
            id: moveDrag
            target: null
            enabled: tile.editing
            onTranslationChanged: if (active)
                tile.dragMoved(tile.gridX + activeTranslation.x, tile.gridY + activeTranslation.y)
            onActiveChanged: if (!active)
                tile.dragEnded()
        }

        // Remove (x), top-right
        StyledRect {
            objectName: "bentoRemove"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Metrics.spacing / 2
            width: Metrics.badgeHeight
            height: Metrics.badgeHeight
            radius: height / 2
            variant: removeArea.containsMouse ? "error" : "common"
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t("bento.remove")

            Text {
                anchors.centerIn: parent
                text: Icons.cancel
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: removeArea.containsMouse ? Styling.srItem("error") : Colors.overBackground
            }

            MouseArea {
                id: removeArea
                anchors.fill: parent
                anchors.margins: -Metrics.spacing / 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.removeRequested()
            }
        }

        // Resize handle, bottom-right
        StyledRect {
            id: handle
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacing / 2
            width: Metrics.badgeHeight
            height: Metrics.badgeHeight
            radius: Styling.radius(-2)
            variant: sizeDrag.active || handleHover.hovered ? "primary" : "common"
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t("bento.resize")

            Text {
                anchors.centerIn: parent
                text: Icons.arrowsOutSimple
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: sizeDrag.active || handleHover.hovered ? Styling.srItem("primary") : Colors.overBackground
            }

            HoverHandler {
                id: handleHover
                cursorShape: Qt.SizeFDiagCursor
            }

            DragHandler {
                id: sizeDrag
                target: null
                onTranslationChanged: if (active)
                    tile.resizeMoved(tile.gridW + activeTranslation.x, tile.gridH + activeTranslation.y)
                onActiveChanged: if (!active)
                    tile.resizeEnded()
            }
        }
    }
}
