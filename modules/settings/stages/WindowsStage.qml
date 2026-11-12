pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "WindowTiles.js" as Tiles
import "../controls/ColorRoleModel.js" as ColorModel

// Stage of the Windows page: your screen (ScreenMini, without its faux
// windows) tiled by the compositor's layout at real pixels: the gaps
// between windows and to the screen edges, the border width and colours,
// the rounding, shadows and the dimming of unfocused windows, all from the
// live values. The focused window is ringed in its border colour. Three
// handles act on it directly: the grip in the gap between windows, the grip
// on the screen edge and the knob in the focused window's corner. A drag
// shows the new value at once and is written as one undo step on release.
Stage {
    id: stage
    objectName: "windowsStage"

    readonly property string layout: String(SettingsStore.get("compositor.layout") || "dwindle")
    readonly property real gapsIn: Number(SettingsStore.get("compositor.gapsIn") ?? 2)
    readonly property real gapsOut: Number(SettingsStore.get("compositor.gapsOut") ?? 4)
    readonly property bool syncWidth: SettingsStore.get("compositor.syncBorderWidth") === true
    readonly property bool syncColor: SettingsStore.get("compositor.syncBorderColor") === true
    readonly property var shellBorder: {
        const bg = SettingsStore.get("theme.srBg");
        return bg && bg.border ? bg.border : ["primary", 0];
    }
    readonly property real border: Math.max(0, Math.min(20, stage.syncWidth ? Number(stage.shellBorder[1] || 0) : Number(SettingsStore.get("compositor.borderSize") ?? 2)))
    readonly property bool syncRound: SettingsStore.get("compositor.syncRoundness") !== false
    readonly property real rounding: Tiles.rounding(stage.syncRound, SettingsStore.get("compositor.rounding"), SettingsStore.get("theme.roundness"))
    readonly property color activeColor: stage.colorOf(stage.syncColor ? stage.shellBorder[0] : SettingsStore.get("compositor.activeBorderColor"), Colors.primary)
    readonly property color inactiveColor: stage.colorOf(SettingsStore.get("compositor.inactiveBorderColor"), Colors.surface)
    readonly property bool shadows: SettingsStore.get("compositor.shadowEnabled") !== false
    readonly property bool dim: SettingsStore.get("compositor.dimInactive") === true
    readonly property real dimStrength: Number(SettingsStore.get("compositor.dimStrength") ?? 0.1)

    // A handle being dragged ("gap" | "edge" | "corner") and the value it
    // shows until the release writes it.
    property string dragging: ""
    property real dragValue: 0
    // A handle under the pointer (its value bubble shows).
    property string hovered: ""
    readonly property real shownGapsIn: stage.dragging === "gap" ? stage.dragValue : stage.gapsIn
    readonly property real shownGapsOut: stage.dragging === "edge" ? stage.dragValue : stage.gapsOut
    readonly property real shownRounding: stage.dragging === "corner" ? stage.dragValue : stage.rounding
    readonly property var tiles: Tiles.tiles(stage.layout, area.width, area.height, stage.shownGapsIn, stage.shownGapsOut)

    // A colour spec (role, "role@alpha", a literal, or a gradient list:
    // its first stop) -> a colour of the live palette.
    function colorOf(spec, fallback) {
        const stops = ColorModel.toStops(spec);
        if (stops.length === 0)
            return fallback;
        const role = ColorModel.roleOf(stops[0]);
        const base = Colors[role] !== undefined ? Colors[role] : Qt.color(role);
        return Qt.alpha(base, ColorModel.alphaOf(stops[0]));
    }

    // Writes the dragged value (one undo step) and ends the drag.
    function commit() {
        const what = stage.dragging, v = stage.dragValue;
        stage.dragging = "";
        if (what === "gap")
            SettingsStore.transaction("prefs.undo.window_gaps", () => SettingsStore.set("compositor.gapsIn", v));
        else if (what === "edge")
            SettingsStore.transaction("prefs.undo.window_gaps", () => SettingsStore.set("compositor.gapsOut", v));
        else if (what === "corner")
            SettingsStore.transaction("prefs.undo.window_corners", () => {
                SettingsStore.set("compositor.syncRoundness", false);
                SettingsStore.set("compositor.rounding", v);
            });
    }

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showWindows: false
        showDock: true

        // The space windows get, at real pixels.
        Item {
            id: area
            objectName: "windowsArea"
            x: mini.freeRect.x
            y: mini.freeRect.y
            width: mini.freeRect.w
            height: mini.freeRect.h

            StageSpot {
                keys: ["compositor.layout", "compositor.smartGaps"]
                spread: 0
                cornerRadius: Space.smallRadius
            }

            Repeater {
                model: stage.tiles.length
                delegate: TiledWindow {
                    required property int index
                    tile: stage.tiles[index]
                    focused: index === 0
                    kind: index
                }
            }

            // The grip on the gap between the first two windows.
            Grip {
                id: gapGrip
                objectName: "windowsGapGrip"
                name: "gap"
                vertical: true
                readonly property var a: stage.tiles[0] || Tiles.rect(0, 0, 0, 0)
                cx: a.x + a.w + stage.shownGapsIn
                cy: a.y + a.h * 0.32
                start: stage.gapsIn
                valueText: I18n.t("prefs.windows.stage.gaps").replace("%1", Math.round(stage.shownGapsIn))
                map: (dx, dy) => Tiles.gapFromDrag(gapGrip.start, dx)
                keys: ["compositor.gapsIn"]
            }

            // The grip on the screen's left edge (the gap to the edges).
            Grip {
                id: edgeGrip
                objectName: "windowsEdgeGrip"
                name: "edge"
                vertical: true
                cx: stage.shownGapsOut / 2
                cy: area.height * 0.5
                start: stage.gapsOut
                valueText: I18n.t("prefs.windows.stage.edges").replace("%1", Math.round(stage.shownGapsOut))
                map: (dx, dy) => Tiles.edgeFromDrag(edgeGrip.start, dx)
                keys: ["compositor.gapsOut"]
            }

            // The knob in the focused window's bottom-left corner.
            Grip {
                id: cornerGrip
                objectName: "windowsCornerGrip"
                name: "corner"
                round: true
                readonly property var a: stage.tiles[0] || Tiles.rect(0, 0, 0, 0)
                readonly property real inset: stage.border + Math.max(Space.m, stage.shownRounding * 0.42)
                cx: a.x + cornerGrip.inset
                cy: a.y + a.h - cornerGrip.inset
                start: stage.rounding
                valueText: I18n.t("prefs.windows.stage.corners").replace("%1", Math.round(stage.shownRounding))
                map: (dx, dy) => Tiles.roundingFromDrag(cornerGrip.start, dx, -dy)
                keys: ["compositor.rounding", "windows.corners"]
            }
        }
    }

    // One window: its shadow, the border ring (focused: the active colour),
    // the body with a title row and text lines, the unfocused dim.
    component TiledWindow: Item {
        id: win

        property var tile: Tiles.rect(0, 0, 0, 0)
        property bool focused: false
        // what the window shows: 0 editor, 1 gallery, 2 player, 3 chat
        property int kind: 0
        readonly property real r: stage.shownRounding
        readonly property bool animate: stage.dragging === "" && Motion.glide.duration > 0

        x: win.tile.x
        y: win.tile.y
        width: win.tile.w
        height: win.tile.h
        objectName: "stageWindow"
        Behavior on x {
            enabled: win.animate
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Behavior on y {
            enabled: win.animate
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Behavior on width {
            enabled: win.animate
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Behavior on height {
            enabled: win.animate
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        RectangularShadow {
            anchors.fill: parent
            visible: stage.shadows
            radius: ring.radius
            blur: Space.l
            spread: 0
            color: Qt.alpha(Colors.shadow, win.focused ? 0.55 : 0.35)
        }

        // The border ring and the body inside it.
        Mark {
            id: ring
            anchors.fill: parent
            radius: win.r > 0 ? win.r + stage.border : 0
            color: stage.border > 0 ? (win.focused ? stage.activeColor : stage.inactiveColor) : "transparent"

            Mark {
                id: body
                anchors.fill: parent
                anchors.margins: stage.border
                radius: win.r
                color: Qt.alpha(win.focused ? Colors.background : Colors.surfaceContainer, 0.9)

                // the window's app: title dots, then an editor, a gallery,
                // a player or a chat
                Item {
                    id: app
                    readonly property real pad: Math.max(Space.s + 2, win.r * 0.55)
                    x: app.pad
                    y: app.pad
                    width: body.width - app.pad * 2
                    height: body.height - app.pad * 2
                    clip: true

                    Row {
                        id: dots
                        spacing: Space.xs
                        Repeater {
                            model: 3
                            delegate: Mark {
                                required property int index
                                width: Space.s
                                height: Space.s
                                color: [Colors.error, Colors.tertiary, Colors.primary][index]
                                opacity: 0.8
                            }
                        }
                    }

                    // editor: lines in a few syntax colours
                    Column {
                        visible: win.kind === 0
                        y: dots.height + Space.m
                        spacing: Space.s
                        Repeater {
                            model: [[0, 0.32, 1], [1, 0.5, 0], [1, 0.62, 2], [2, 0.4, 0], [1, 0.56, 1], [1, 0.28, 0], [0, 0.18, 2], [0, 0.44, 1], [1, 0.36, 0]]
                            delegate: Mark {
                                required property var modelData
                                x: modelData[0] * Space.l
                                width: modelData[1] * app.width
                                height: Space.xs + 1
                                color: Qt.alpha([Type.text, Colors.primary, Colors.tertiary][modelData[2]], modelData[2] === 0 ? 0.2 : 0.55)
                            }
                        }
                    }

                    // gallery: a grid of tinted pictures
                    Grid {
                        id: gallery
                        visible: win.kind === 1
                        y: dots.height + Space.s
                        columns: 3
                        spacing: Space.xs
                        readonly property real cell: (app.width - spacing * 2) / 3
                        Repeater {
                            model: 6
                            delegate: Mark {
                                required property int index
                                width: gallery.cell
                                height: Math.min(gallery.cell * 0.7, (app.height - dots.height - Space.s * 2) / 2)
                                radius: Math.min(win.r * 0.5, Space.smallRadius)
                                color: Qt.alpha([Colors.primary, Colors.tertiary, Colors.secondary][index % 3], 0.18 + (index % 2) * 0.14)
                            }
                        }
                    }

                    // player: cover, two lines and the progress
                    Row {
                        visible: win.kind === 2
                        y: dots.height + Space.s
                        spacing: Space.m
                        Mark {
                            width: Math.min(app.height - dots.height - Space.s, Space.xxl + Space.l)
                            height: width
                            radius: Math.min(win.r * 0.6, width / 2)
                            color: Qt.alpha(Colors.primary, 0.45)
                        }
                        Column {
                            spacing: Space.s
                            anchors.verticalCenter: parent.verticalCenter
                            Mark {
                                width: app.width * 0.36
                                height: Space.xs + 2
                                color: Qt.alpha(Type.text, 0.45)
                            }
                            Mark {
                                width: app.width * 0.24
                                height: Space.xs + 1
                                color: Qt.alpha(Type.text, 0.2)
                            }
                            Mark {
                                width: app.width * 0.46
                                height: Space.xs - 1
                                color: Type.track
                                Mark {
                                    width: parent.width * 0.38
                                    height: parent.height
                                    color: Colors.primary
                                }
                            }
                        }
                    }

                    // chat: bubbles on both sides
                    Column {
                        visible: win.kind === 3
                        y: dots.height + Space.s
                        width: app.width
                        spacing: Space.xs + 2
                        Repeater {
                            model: [[0, 0.6], [1, 0.42], [0, 0.34]]
                            delegate: Mark {
                                required property var modelData
                                x: modelData[0] === 1 ? app.width - width : 0
                                width: app.width * modelData[1]
                                height: Space.l
                                radius: Math.min(win.r * 0.5 + Space.xs, height / 2)
                                color: modelData[0] === 1 ? Qt.alpha(Colors.primary, 0.4) : Qt.alpha(Type.text, 0.1)
                            }
                        }
                    }
                }

                // decoration:dim_inactive darkens unfocused windows.
                Mark {
                    anchors.fill: parent
                    radius: body.radius
                    visible: !win.focused && stage.dim
                    color: Qt.alpha(Colors.shadow, Math.min(0.65, 0.3 + stage.dimStrength * 1.5))
                    StageSpot {
                        keys: ["compositor.dimInactive"]
                        spread: 0
                        cornerRadius: body.radius
                    }
                }
            }
        }

        StageSpot {
            visible: win.focused || opacity > 0
            keys: win.focused ? ["compositor.borderSize", "compositor.activeBorderColor", "windows.border", "compositor.shadowEnabled"] : ["compositor.inactiveBorderColor"]
            spread: Space.xs
            cornerRadius: ring.radius
        }
    }

    // A handle on the stage: a grip (bar) or a knob (round) at (cx, cy)
    // that maps a drag to a value; hover or drag shows the value beside it.
    component Grip: Item {
        id: grip

        property string name: ""
        property bool vertical: false
        property bool round: false
        property real cx: 0
        property real cy: 0
        property real start: 0
        property string valueText: ""
        property var map: null
        property var keys: []
        readonly property bool active: stage.dragging === grip.name || stage.hovered === grip.name
        property point pressAt: Qt.point(0, 0)

        x: grip.cx - width / 2
        y: grip.cy - height / 2
        width: Space.xl
        height: grip.round ? Space.xl : Space.xxl + Space.l
        z: 20

        Mark {
            anchors.centerIn: parent
            width: grip.round ? Space.l + (grip.active ? Space.xs : 0) : Space.s - 2 + (grip.active ? 2 : 0)
            height: grip.round ? width : Space.xxl + (grip.active ? Space.s : 0)
            color: grip.active ? Type.accent : Type.text
            border.width: grip.round ? Space.stroke : Space.hairline
            border.color: Qt.alpha(Colors.shadow, 0.6)
            Behavior on height {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                }
            }
        }

        StageSpot {
            keys: grip.keys
            spread: 0
            cornerRadius: Space.smallRadius
        }

        // The value while hovered or dragged.
        Mark {
            objectName: grip.objectName + "Value"
            visible: grip.active
            x: grip.width + Space.xs
            y: (grip.height - height) / 2
            width: valueLabel.implicitWidth + Space.m * 2
            height: valueLabel.implicitHeight + Space.xs * 2
            color: Look.raisedFill(false)
            border.width: Space.hairline
            border.color: Type.hairline
            KitText {
                id: valueLabel
                anchors.centerIn: parent
                role: "caption"
                color: Type.text
                text: grip.valueText
            }
        }

        MouseArea {
            objectName: grip.objectName + "Area"
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: grip.round ? Qt.SizeFDiagCursor : Qt.SizeHorCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    stage.hovered = grip.name;
                else if (stage.hovered === grip.name)
                    stage.hovered = "";
            }
            onPressed: mouse => {
                grip.pressAt = mapToItem(area, mouse.x, mouse.y);
                stage.dragValue = grip.start;
                stage.dragging = grip.name;
            }
            onPositionChanged: mouse => {
                if (stage.dragging !== grip.name)
                    return;
                const p = mapToItem(area, mouse.x, mouse.y);
                stage.dragValue = grip.map(p.x - grip.pressAt.x, p.y - grip.pressAt.y);
            }
            onReleased: stage.commit()
            onCanceled: stage.dragging = ""
        }
    }
}
