import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.globals
import qs.config
import "../Ui.js" as Ui
import "../../services/DisplayModel.js" as DisplayModel
import "DisplayFormat.js" as DisplayFormat

// One monitor on the arrangement canvas: a rounded pane with a dimmed
// wallpaper thumbnail, number badge, model and connector. Dragging moves it
// (the canvas arranges on release and the tile glides to the snapped spot).
StyledRect {
    id: tile

    required property var config
    property var output: null
    property int number: 0
    property bool selected: false
    // Canvas mapping (logical px -> canvas px)
    property real pxScale: 0.1
    property real originX: 0
    property real originY: 0
    readonly property bool animate: Config.animDuration > 0
    readonly property var logical: DisplayModel.logicalSize(config)
    readonly property real baseX: originX + config.x * pxScale
    readonly property real baseY: originY + config.y * pxScale
    readonly property string wallpaper: {
        const m = GlobalStates.wallpaperManager;
        const f = m ? (m.currentWallpaper || "") : "";
        return f && m.getDisplaySource ? m.getDisplaySource(f) : f;
    }
    property bool dragging: false
    // Offset from the layout position: the drag distance, then the glide back to 0
    property real gx: 0
    property real gy: 0

    signal picked
    // Drop position in logical px
    signal dropped(real lx, real ly)

    variant: selected ? "focus" : "pane"
    radius: Math.min(Styling.radius(4), 22)
    width: Math.max(logical.w * pxScale, 8)
    height: Math.max(logical.h * pxScale, 8)
    x: baseX + gx
    y: baseY + gy
    z: dragging ? 5 : (selected ? 2 : 1)
    scale: dragging ? 1.02 : 1
    enableShadow: dragging

    Behavior on width {
        enabled: tile.animate && !tile.dragging
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on height {
        enabled: tile.animate && !tile.dragging
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on scale {
        enabled: tile.animate
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Motion.morph.easing
        }
    }

    // A moved layout position glides instead of jumping (snap, push-out, renormalise).
    property real _lastX: baseX
    property real _lastY: baseY
    onBaseXChanged: {
        const d = _lastX - baseX;
        _lastX = baseX;
        if (animate && !dragging && Math.abs(d) > 0.5) {
            gx += d;
            glide.restart();
        }
    }
    onBaseYChanged: {
        const d = _lastY - baseY;
        _lastY = baseY;
        if (animate && !dragging && Math.abs(d) > 0.5) {
            gy += d;
            glide.restart();
        }
    }

    ParallelAnimation {
        id: glide
        NumberAnimation {
            target: tile
            property: "gx"
            to: 0
            duration: Config.animDuration * 1.3
            easing.type: Motion.emphasis.easing
            easing.overshoot: 1.4
        }
        NumberAnimation {
            target: tile
            property: "gy"
            to: 0
            duration: Config.animDuration * 1.3
            easing.type: Motion.emphasis.easing
            easing.overshoot: 1.4
        }
    }

    Image {
        anchors.fill: parent
        source: tile.wallpaper !== "" ? (tile.wallpaper.startsWith("/") ? "file://" + tile.wallpaper : tile.wallpaper) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 320
        sourceSize.height: 320
        asynchronous: true
        cache: true
        opacity: 0.35
    }

    // Number badge
    Rectangle {
        id: badge
        x: 10
        y: 10
        width: 26
        height: 26
        radius: width / 2
        visible: tile.height > 52
        color: tile.selected ? Colors.primary : Ui.alpha(Colors.overBackground, 0.14)
        Text {
            anchors.centerIn: parent
            text: tile.number
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Bold
            color: tile.selected ? Colors.overPrimary : Colors.overBackground
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: tile.height < 110 ? 10 : 0
        width: parent.width - 24
        spacing: 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: DisplayFormat.title(tile.output, tile.config)
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        Text {
            width: parent.width
            visible: tile.height > 60
            horizontalAlignment: Text.AlignHCenter
            text: tile.config.name
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
        Text {
            width: parent.width
            visible: tile.height > 84
            horizontalAlignment: Text.AlignHCenter
            text: DisplayFormat.formatResolution(tile.config.width, tile.config.height) + (tile.config.refresh > 0 ? "  \u00b7  " + DisplayFormat.formatHz(tile.config.refresh) : "")
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }

    // Selection outline
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: "transparent"
        border.width: tile.selected ? 2 : 1
        border.color: tile.selected ? Colors.primary : Ui.alpha(Colors.outline, area.containsMouse ? 0.7 : 0.4)
        Behavior on border.color {
            enabled: tile.animate
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real startX: 0
        property real startY: 0

        onPressed: mouse => {
            tile.picked();
            const p = mapToItem(tile.parent, mouse.x, mouse.y);
            startX = p.x;
            startY = p.y;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(tile.parent, mouse.x, mouse.y);
            if (!tile.dragging && Math.abs(p.x - startX) + Math.abs(p.y - startY) < 5)
                return;
            glide.stop();
            tile.dragging = true;
            tile.gx = p.x - startX;
            tile.gy = p.y - startY;
        }
        onReleased: {
            if (!tile.dragging)
                return;
            const fromX = tile.baseX + tile.gx;
            const fromY = tile.baseY + tile.gy;
            tile.dropped((fromX - tile.originX) / tile.pxScale, (fromY - tile.originY) / tile.pxScale);
            // The layout updated synchronously: glide from where the tile was dropped.
            tile.gx = fromX - tile.baseX;
            tile.gy = fromY - tile.baseY;
            tile.dragging = false;
            tile._lastX = tile.baseX;
            tile._lastY = tile.baseY;
            glide.restart();
        }
        onCanceled: {
            tile.dragging = false;
            tile.gx = 0;
            tile.gy = 0;
        }
    }
}
