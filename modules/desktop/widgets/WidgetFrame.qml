import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.components.kit
import qs.modules.desktop.widgets
import "WidgetRegistry.js" as Registry
import "../../widgets/dashboard/widgets/WidgetRegistry.js" as Shared
import "WidgetGeometry.js" as Geometry
// Types are loaded by URL from the registry; the directory import makes
// Quickshell's scanner include types/.
import "types" as WidgetTypes

// One placed widget: its surface (StyledRect in desktop.widgetVariant, glass
// surface "widgets") with the type loaded inside, and in edit mode the
// chrome to move (drag anywhere), resize (corner handle) and remove it.
// Geometry follows the config; while dragging, a local rect is shown and
// committed (relative to the screen) on release.
Item {
    id: root

    property var widget: null
    property real screenW: 1
    property real screenH: 1
    // Allowed area in screen pixels (outside the bar / frame).
    property var bounds: Geometry.rect(0, 0, screenW, screenH)
    property int grid: 0
    property bool editing: false
    property bool active: true
    property bool preview: false
    property var clockArea: null

    signal committed(var rel)
    signal removeRequested
    signal optionChanged(string key, var value)

    readonly property var type: widget ? Registry.get(widget.type) : null
    // The loaded type (DesktopWidget), null until loaded.
    readonly property Item body: content.item as Item
    readonly property var stored: widget ? Geometry.toPixels(widget, screenW, screenH) : Geometry.rect(0, 0, 0, 0)
    property var live: null
    readonly property var geom: live ?? stored
    readonly property var minPx: {
        const m = Registry.minFraction(widget?.type ?? "", screenW, screenH);
        return {
            w: Math.round(m.w * screenW),
            h: Math.round(m.h * screenH)
        };
    }
    readonly property bool overlapsClock: editing && Geometry.overlaps(geom, clockArea)
    readonly property real k: {
        if (!type)
            return 1;
        const s = Registry.scaleFor(screenH);
        return Math.max(0.6, Math.min(3, Math.min(geom.w / (type.size.w * s), geom.h / (type.size.h * s))));
    }

    objectName: "widgetFrame:" + (widget?.id ?? "")
    x: geom.x
    y: geom.y
    width: geom.w
    height: geom.h

    Behavior on x {
        enabled: root.live === null && Config.animDuration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on y {
        enabled: root.live === null && Config.animDuration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    // Appear softly; lift a little while dragged.
    opacity: 0
    scale: drag.pressed || resize.pressed ? 1.015 : 1
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }
    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.exit.duration
            easing.type: Motion.morph.easing
        }
    }

    StyledRect {
        id: surface
        anchors.fill: parent
        variant: Config.desktop.widgetVariant ?? "pane"
        glassSurface: "widgets"
        radius: Math.min(Look.radius("surface"), Math.min(width, height) / 4)
        enableShadow: true

        Loader {
            id: content
            anchors.fill: parent
            active: root.type !== null
            source: root.type ? Qt.resolvedUrl(root.type.shared ? "../../widgets/dashboard/widgets/" + Shared.byId(root.type.shared).url : "types/" + root.type.file) : ""
            onLoaded: {
                // Desktop-only types and shared bento widgets take the same
                // optional inputs; each declares only the ones it uses.
                const w = item;
                const inputs = {
                    "widget": () => root.widget,
                    "options": () => Registry.options(root.widget),
                    "ink": () => surface.item,
                    "active": () => root.active,
                    "preview": () => root.preview,
                    "editing": () => root.editing,
                    "k": () => root.k,
                    "compact": () => root.width < 200 || root.height < 160,
                    "animationsEnabled": () => root.active && !root.preview
                };
                for (const name in inputs)
                    if (w[name] !== undefined)
                        w[name] = Qt.binding(inputs[name]);
                // The desktop surface is the frame; no debug buttons.
                const off = ["framed", "showDebugControls"];
                for (const name of off)
                    if (w[name] !== undefined)
                        w[name] = false;
                root.relayOptions(w);
            }
        }
    }

    // Desktop-only types report option edits (the note text); shared ones don't.
    function relayOptions(target: var): void {
        if (target.optionChanged)
            target.optionChanged.connect((key, value) => root.optionChanged(key, value));
    }

    // ---- edit chrome ----

    // Edit outline: the widget is the selected / grabbed object.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Space.stroke
        radius: surface.radius + Space.stroke
        color: "transparent"
        border.width: Space.stroke - 1
        border.color: root.overlapsClock ? Type.danger : Type.accent
        opacity: root.editing ? (drag.containsMouse || drag.pressed || resize.pressed ? 1 : 0.6) : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.editing
        visible: enabled
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point origin
        property var start
        onPressed: mouse => {
            origin = mapToItem(root.parent, mouse.x, mouse.y);
            start = root.geom;
            root.live = start;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.parent, mouse.x, mouse.y);
            root.live = Geometry.moved(start, p.x - origin.x, p.y - origin.y, root.bounds, root.grid);
        }
        onReleased: root.finish()
        onCanceled: root.live = null
    }

    function finish() {
        const r = live;
        if (r && (r.x !== stored.x || r.y !== stored.y || r.w !== stored.w || r.h !== stored.h))
            committed(Geometry.toRelative(r, screenW, screenH));
        live = null;
    }

    // Type label above the widget.
    Chip {
        visible: root.editing
        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: Space.s
        dense: true
        icon: Icons[root.type?.icon ?? ""] ?? ""
        text: root.type ? I18n.t(root.type.labelKey) : ""
    }

    IconButton {
        objectName: "removeWidget"
        visible: root.editing
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Space.s
        size: "xs"
        icon: Icons.cancel
        tooltip: I18n.t("desktop.widgets.remove")
        danger: true
        primary: true
        Accessible.name: I18n.t("desktop.widgets.remove")
        onClicked: root.removeRequested()
    }

    // Overlap warning: the depth clock is drawn under the subject, so a
    // widget over it hides the clock.
    Chip {
        visible: root.overlapsClock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.s
        dense: true
        danger: true
        active: true
        icon: Icons.warning
        text: I18n.t("desktop.widgets.overlaps_clock")
        maxLabelWidth: Math.max(0, root.width - Space.xxl * 2)
    }

    // Resize handle: an accent knob on the corner of the grabbed widget.
    Rectangle {
        id: handle
        visible: root.editing
        width: Space.keyHint
        height: Space.keyHint
        radius: Look.radius("round", height)
        x: parent.width - width / 2 - Space.xs
        y: parent.height - height / 2 - Space.xs
        color: Type.accent
        border.width: Space.stroke - 1
        border.color: Type.accentInk
        scale: resize.containsMouse || resize.pressed ? 1.15 : 1
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }

        MouseArea {
            id: resize
            objectName: "resizeWidget"
            anchors.fill: parent
            anchors.margins: -Space.s
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            property point origin
            property var start
            onPressed: mouse => {
                origin = mapToItem(root.parent, mouse.x, mouse.y);
                start = root.geom;
                root.live = start;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = mapToItem(root.parent, mouse.x, mouse.y);
                root.live = Geometry.resized(start, p.x - origin.x, p.y - origin.y, root.minPx, root.bounds, root.grid);
            }
            onReleased: root.finish()
            onCanceled: root.live = null
        }
    }
}
