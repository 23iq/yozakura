pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.controls
import qs.config
import "../Ui.js" as Ui
import "WindowsPreviewModel.js" as Model
import "../../services/CompositorAppearance.js" as Appearance

// Two tiled windows over a 1:1 slice of the real wallpaper, drawn from the
// exact hl.config() table the shell applies (CompositorAppearance): gaps,
// border width/gradient/angle, rounding, shadows, blur behind translucent
// windows, window opacity and inactive dimming.
PreviewStage {
    id: root

    property var entry
    stageHeight: 250

    readonly property var c: Config.compositor
    readonly property var theme: Config.theme
    // Torn down after Config at shutdown: never read a null domain.
    readonly property var hl: !c || !theme ? Appearance.buildHyprlandConfig({
        "compositor": {},
        "resolve": () => Qt.rgba(0, 0, 0, 0)
    }) : Appearance.buildHyprlandConfig({
        "compositor": c,
        "resolve": spec => {
            const r = Config.resolveColor(spec);
            return typeof r === "string" ? Qt.color(r) : r;
        },
        "borderSize": c.syncBorderWidth ? ((theme.srBg && theme.srBg.border && theme.srBg.border[1]) || 0) : c.borderSize,
        "rounding": c.syncRoundness ? Config.roundness : c.rounding,
        "borderColor": c.syncBorderColor ? ((theme.srBg && theme.srBg.border && theme.srBg.border[0]) || "primary") : (c.activeBorderColor && c.activeBorderColor.length > 0 ? c.activeBorderColor[0] : "primary"),
        "shadowColor": c.syncShadowColor ? theme.shadowColor : c.shadowColor,
        "shadowOpacity": c.syncShadowOpacity ? theme.shadowOpacity : c.shadowOpacity,
        "glass": Glass.compositor
    })
    readonly property var deco: hl.decoration
    readonly property int borderSize: hl.general.border_size
    readonly property int rounding: deco.rounding
    readonly property var tiles: Model.tiles(scene.width, scene.height, hl.general.gaps_in, hl.general.gaps_out)
    readonly property real blurAmount: Model.blurAmount(deco.blur)

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: manager && manager.currentWallpaper ? (manager.getColorSource ? manager.getColorSource(manager.currentWallpaper) : manager.currentWallpaper) : ""
    // The slice is shown at screen pixels: the wallpaper is laid out at the
    // screen's size and centered behind the stage.
    readonly property int screenWidth: Screen.width > 0 ? Screen.width : 1920
    readonly property int screenHeight: Screen.height > 0 ? Screen.height : 1080

    Item {
        id: scene
        anchors.fill: parent
        clip: true

        ScreenBackdrop {
            id: fallback
            anchors.fill: parent
            radius: 0
            visible: wall.status !== Image.Ready
        }

        Image {
            id: wall
            width: Math.max(root.screenWidth, scene.width)
            height: Math.max(root.screenHeight, scene.height)
            x: (scene.width - width) / 2
            y: (scene.height - height) / 2
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.screenWidth
            visible: status === Image.Ready
        }

        Repeater {
            model: 2
            delegate: PreviewWindow {
                required property int index
                tile: root.tiles[index]
                focused: index === 0
            }
        }
    }

    // Readout of the numbers the preview is drawn with.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: readout.implicitWidth + 18
        height: readout.implicitHeight + 10
        radius: Math.min(Styling.radius(0), 12)
        color: Ui.alpha(Colors.surfaceContainerLowest, 0.82)
        Text {
            id: readout
            objectName: "windowsReadout"
            anchors.centerIn: parent
            readonly property string template: I18n.t("prefs.windows.preview.readout")
            text: template.replace("%1", root.hl.general.gaps_in).replace("%2", root.hl.general.gaps_out).replace("%3", root.borderSize).replace("%4", root.rounding)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            color: Colors.overSurfaceVariant
        }
    }

    // One window: shadow, blurred wallpaper behind its translucent body,
    // mock content, inactive dim and the (gradient) border ring.
    component PreviewWindow: Item {
        id: win

        property var tile: ({
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            })
        property bool focused: false
        readonly property var shadow: root.deco.shadow
        readonly property var ring: Model.border(focused ? root.hl.general.col.active_border : root.hl.general.col.inactive_border)
        readonly property real outerRadius: root.rounding > 0 ? root.rounding + root.borderSize : 0
        readonly property real bodyOpacity: (focused ? root.deco.active_opacity : root.deco.inactive_opacity) * (focused ? Glass.terminalOpacity : 1)
        readonly property var shadowOffset: Model.offset(shadow.offset)

        x: tile.x
        y: tile.y
        width: tile.w
        height: tile.h

        RectangularShadow {
            visible: win.shadow.enabled && win.shadow.range > 0
            anchors.centerIn: parent
            width: parent.width * win.shadow.scale
            height: parent.height * win.shadow.scale
            offset: Qt.vector2d(win.shadowOffset.x, win.shadowOffset.y)
            radius: win.outerRadius
            // render_power 1..4: higher = faster falloff (shorter visible glow).
            blur: win.shadow.sharp ? 0 : win.shadow.range * (1.3 - 0.15 * win.shadow.render_power)
            spread: win.shadow.sharp ? win.shadow.range : 0
            color: Model.qtColor(win.focused ? win.shadow.color : win.shadow.color_inactive)
        }

        // Window body (inside the border).
        Item {
            id: body
            x: root.borderSize
            y: root.borderSize
            width: parent.width - 2 * root.borderSize
            height: parent.height - 2 * root.borderSize

            // Compositor blur: the wallpaper under the body, blurred and
            // masked to the window's rounded shape.
            ShaderEffectSource {
                id: slice
                readonly property Item backdrop: wall.visible ? wall : fallback
                anchors.fill: parent
                visible: false
                sourceItem: backdrop
                sourceRect: Qt.rect(win.x + body.x - backdrop.x, win.y + body.y - backdrop.y, body.width, body.height)
            }
            Rectangle {
                id: bodyMask
                anchors.fill: parent
                radius: root.rounding
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: win.bodyOpacity < 1
                source: slice
                blurEnabled: root.blurAmount > 0
                blur: root.blurAmount
                blurMax: 48
                saturation: root.deco.blur.vibrancy ?? 0
                brightness: (root.deco.blur.brightness ?? 1) - 1
                contrast: (root.deco.blur.contrast ?? 1) - 1
                maskEnabled: true
                maskSource: bodyMask
            }

            Rectangle {
                anchors.fill: parent
                radius: root.rounding
                color: Ui.alpha(win.focused ? Colors.background : Colors.surfaceContainer, win.bodyOpacity)

                Column {
                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 7
                    clip: true

                    Row {
                        spacing: 6
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                width: 9
                                height: 9
                                radius: 4.5
                                color: [Colors.error, Colors.tertiary, Colors.primary][index]
                                opacity: 0.85
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.focused ? "~ ❯ hyprctl activewindow" : I18n.t("prefs.windows.preview.inactive")
                        font.family: win.focused ? Config.theme.monoFont : Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: win.focused ? Colors.primary : Colors.overSurfaceVariant
                    }
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: (0.85 - index * 0.17) * parent.width
                            height: 7
                            radius: 3.5
                            color: Ui.alpha(Colors.overBackground, win.focused ? 0.16 : 0.1)
                        }
                    }
                }
            }

            // decoration:dim_inactive darkens unfocused windows.
            Rectangle {
                anchors.fill: parent
                radius: root.rounding
                visible: !win.focused && root.deco.dim_inactive
                color: Qt.rgba(0, 0, 0, root.deco.dim_strength)
            }
        }

        // Border ring: outer rounded rect filled with the gradient, inner cut out.
        Canvas {
            id: ringCanvas
            anchors.fill: parent
            visible: root.borderSize > 0
            readonly property var paintKey: [win.ring.colors.join(","), win.ring.angle, root.borderSize, win.outerRadius, root.rounding, width, height].join("|")
            onPaintKeyChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height, b = root.borderSize;
                if (w <= 0 || h <= 0)
                    return;
                const line = Model.gradientLine(win.ring.angle, w, h);
                const g = ctx.createLinearGradient(line.x1, line.y1, line.x2, line.y2);
                const cols = win.ring.colors;
                for (let i = 0; i < cols.length; i++)
                    g.addColorStop(cols.length > 1 ? i / (cols.length - 1) : 0, cols[i]);
                if (cols.length === 1)
                    g.addColorStop(1, cols[0]);
                function rounded(x, y, rw, rh, r) {
                    const rr = Math.max(0, Math.min(r, rw / 2, rh / 2));
                    ctx.moveTo(x + rr, y);
                    ctx.arcTo(x + rw, y, x + rw, y + rh, rr);
                    ctx.arcTo(x + rw, y + rh, x, y + rh, rr);
                    ctx.arcTo(x, y + rh, x, y, rr);
                    ctx.arcTo(x, y, x + rw, y, rr);
                    ctx.closePath();
                }
                ctx.beginPath();
                rounded(0, 0, w, h, win.outerRadius);
                rounded(b, b, w - 2 * b, h - 2 * b, root.rounding);
                ctx.fillStyle = g;
                ctx.fillRule = Qt.OddEvenFill;
                ctx.fill();
            }
        }
    }
}
