import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
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
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: root.live === null && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    // Appear softly; lift a little while dragged.
    opacity: 0
    scale: drag.pressed || resize.pressed ? 1.015 : 1
    Component.onCompleted: opacity = 1
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    StyledRect {
        id: surface
        anchors.fill: parent
        variant: Config.desktop.widgetVariant ?? "pane"
        glassSurface: "widgets"
        radius: Math.min(Styling.radius(4), Math.min(width, height) / 4)
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

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: surface.radius + 3
        color: "transparent"
        border.width: 2
        border.color: root.overlapsClock ? Colors.error : Colors.primary
        opacity: root.editing ? (drag.containsMouse || drag.pressed || resize.pressed ? 1 : 0.6) : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
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
    Row {
        visible: root.editing
        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        spacing: 6

        Rectangle {
            height: 24
            width: chip.implicitWidth + 18
            radius: 12
            color: Qt.rgba(Colors.surfaceContainerHighest.r, Colors.surfaceContainerHighest.g, Colors.surfaceContainerHighest.b, 0.92)
            Text {
                id: chip
                anchors.centerIn: parent
                text: (Icons[root.type?.icon ?? ""] ?? "") + "  " + (root.type ? I18n.t(root.type.labelKey) : "")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.DemiBold
                color: Colors.overSurface
            }
        }
    }

    WidgetButton {
        objectName: "removeWidget"
        visible: root.editing
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        size: 28
        icon: "cancel"
        label: I18n.t("desktop.widgets.remove")
        ink: Colors.overError
        fill: Colors.error
        hoverFill: Qt.lighter(Colors.error, 1.15)
        onClicked: root.removeRequested()
    }

    // Overlap warning: the depth clock is drawn under the subject, so a
    // widget over it hides the clock.
    Rectangle {
        visible: root.overlapsClock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 26
        width: Math.min(parent.width - 20, warn.implicitWidth + 22)
        radius: 13
        color: Colors.error
        Text {
            id: warn
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Icons.warning + "  " + I18n.t("desktop.widgets.overlaps_clock")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.DemiBold
            color: Colors.overError
        }
    }

    Rectangle {
        id: handle
        visible: root.editing
        width: 22
        height: 22
        radius: 11
        x: parent.width - width / 2 - 4
        y: parent.height - height / 2 - 4
        color: Colors.primary
        border.width: 2
        border.color: Colors.overPrimary
        scale: resize.containsMouse || resize.pressed ? 1.15 : 1
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 3
            }
        }

        MouseArea {
            id: resize
            objectName: "resizeWidget"
            anchors.fill: parent
            anchors.margins: -6
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
