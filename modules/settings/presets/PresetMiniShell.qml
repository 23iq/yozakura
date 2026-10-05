pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import "../Ui.js" as Ui
import "../../../config/ColorSpec.js" as ColorSpec

// Miniature of the shell for a preset's look (`preset list --json` look:
// bar edge/style/frame, notch, dock, roundness, gaps, borders, window
// rounding, desktop clock, numerals, light/dark/OLED) drawn over the
// user's wallpaper with the palette the preset's matugen scheme gives that
// wallpaper. Missing palette roles fall back to the live Colors.
Item {
    id: root

    property var look: ({})
    property var colorMap: null
    property string wallpaper: ""
    // true once the wallpaper decoded (or there is none): safe to grab.
    readonly property bool ready: wallpaper === "" || wall.status === Image.Ready || wall.status === Image.Error

    // UI unit: the screen is drawn as if 1000 px wide, so bars and gaps
    // stay legible at card size.
    readonly property real u: width / 1000

    function v(key, fallback) {
        const x = look ? look[key] : undefined;
        return x === undefined || x === null ? fallback : x;
    }
    function c(role) {
        const p = colorMap;
        if (p && p[role])
            return Qt.color(p[role]);
        return Colors[role] ?? Colors.surface;
    }
    // Compositor border colors: a list of specs ("primary", "#hex",
    // "surfaceBright@0.5", see config/ColorSpec.js); the first one is drawn.
    function borderColor(list, fallback) {
        const spec = ColorSpec.parse(Array.isArray(list) && list.length ? String(list[0]) : fallback);
        const base = String(spec.base).charAt(0) === "#" ? Qt.color(spec.base) : c(spec.base);
        return spec.alpha === null ? base : Ui.alpha(base, spec.alpha);
    }

    readonly property string edge: v("bar.position", "top")
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool islands: v("bar.layout.style", "classic") === "islands"
    readonly property bool frame: v("bar.frameEnabled", false)
    readonly property bool contained: frame || v("bar.containBar", false)
    readonly property bool glass: v("theme.glass.enabled", true) && v("theme.glass.amount", -1) !== 0
    readonly property real radius: Math.max(0, v("theme.roundness", 16)) * u
    readonly property real barThick: (v("bar.compact", false) ? 34 : 42) * u
    readonly property real frameThick: frame ? Math.max(1.5, v("bar.frameThickness", 6) * u) : 0
    readonly property real gapOut: Math.max(1, v("compositor.gapsOut", 4) * u * 1.5)
    readonly property real gapIn: Math.max(1, v("compositor.gapsIn", 2) * u * 1.5)
    readonly property color chrome: Ui.alpha(c("background"), glass ? 0.86 : 1)
    readonly property bool dockOn: v("dock.enabled", true)
    readonly property string dockTheme: v("dock.theme", "default")
    readonly property string dockEdge: v("dock.position", "bottom")
    readonly property bool clockOn: v("desktop.depthClock", false)
    // bar.panels (multi-panel layouts) replace the legacy single bar
    readonly property var panels: {
        // Model data may hand the list over as an array-like wrapper
        const p = v("bar.panels", []);
        const list = p && typeof p.length === "number" ? JSON.parse(JSON.stringify(Array.from(p))) : [];
        return list.filter(x => x && x.enabled !== false);
    }
    readonly property bool usePanels: panels.length > 0

    // Insets of the chrome (frame + attached bar) on each side.
    function inset(side) {
        let n = frameThick;
        if (usePanels)
            return n;
        if (side === edge && (contained || !islands))
            n = Math.max(n, barThick);
        return n;
    }
    readonly property real insetTop: inset("top")
    readonly property real insetBottom: inset("bottom")
    readonly property real insetLeft: inset("left")
    readonly property real insetRight: inset("right")
    // Space a floating bar or a dock takes on its edge.
    function reserve(side) {
        let n = 0;
        if (usePanels)
            n = miniPanels.depths[side] ?? 0;
        else if (side === edge && islands && !contained)
            n = barThick + gapOut;
        if (dockOn && dockTheme !== "integrated" && side === dockEdge)
            n += v("dock.height", 48) * u * (dockTheme === "floating" ? 1.25 : 1);
        return n;
    }

    clip: true

    // Wallpaper
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ui.mix(root.c("surfaceContainerLow"), root.c("primaryContainer"), 0.45)
            }
            GradientStop {
                position: 1
                color: Ui.mix(root.c("surfaceContainerLow"), root.c("tertiaryContainer"), 0.55)
            }
        }
    }
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper ? (root.wallpaper.startsWith("/") ? "file://" + root.wallpaper : root.wallpaper) : ""
        sourceSize.width: 640
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    Rectangle {
        anchors.fill: parent
        color: root.v("theme.lightMode", false) ? "#ffffff" : "#000000"
        opacity: root.v("theme.oledMode", false) ? 0.35 : 0.08
    }

    // Desktop clock
    Column {
        visible: root.clockOn
        x: root.insetLeft + root.reserve("left") + root.width * 0.05
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * root.u
        readonly property bool poster: root.v("desktop.depthClockStyle", "yozakura") === "poster"
        Text {
            text: "21:47"
            font.family: root.v("theme.font", "")
            font.pixelSize: (parent.poster ? 150 : 110) * root.u
            font.weight: parent.poster ? Font.Black : Font.Light
            color: root.c("overBackground")
            opacity: 0.92
        }
        Text {
            text: parent.poster ? "SUNDAY" : "日曜日 · 10月5日"
            font.family: root.v("theme.font", "")
            font.pixelSize: 26 * root.u
            font.letterSpacing: parent.poster ? 6 * root.u : 0
            color: root.c("primary")
        }
    }

    // Windows (dwindle: master + two stacked)
    Item {
        id: work
        readonly property real x0: root.insetLeft + root.reserve("left") + root.gapOut
        readonly property real y0: root.insetTop + root.reserve("top") + root.gapOut
        readonly property real x1: root.width - root.insetRight - root.reserve("right") - root.gapOut
        readonly property real y1: root.height - root.insetBottom - root.reserve("bottom") - root.gapOut
        // The left part shows the wallpaper (and the desktop clock).
        x: x0 + (x1 - x0) * (root.clockOn ? 0.44 : 0.36)
        y: y0
        width: x1 - x
        height: y1 - y0

        readonly property real winRadius: (root.v("compositor.syncRoundness", true) ? root.v("theme.roundness", 16) : root.v("compositor.rounding", 16)) * root.u
        readonly property real border: root.v("compositor.borderSize", 2) > 0 ? Math.max(1, root.v("compositor.borderSize", 2) * root.u) : 0

        MiniWindow {
            x: 0
            y: 0
            width: (parent.width - root.gapIn) * 0.58
            height: parent.height
            focused: true
        }
        MiniWindow {
            x: (parent.width - root.gapIn) * 0.58 + root.gapIn
            y: 0
            width: parent.width - x
            height: (parent.height - root.gapIn) / 2
        }
        MiniWindow {
            x: (parent.width - root.gapIn) * 0.58 + root.gapIn
            y: (parent.height - root.gapIn) / 2 + root.gapIn
            width: parent.width - x
            height: (parent.height - root.gapIn) / 2
            lines: 2
        }
    }

    component MiniWindow: Item {
        id: win
        property bool focused: false
        property int lines: 4

        Rectangle {
            visible: root.v("compositor.shadowEnabled", true)
            anchors.fill: parent
            anchors.topMargin: 3 * root.u
            anchors.leftMargin: 1 * root.u
            anchors.rightMargin: -1 * root.u
            anchors.bottomMargin: -5 * root.u
            radius: work.winRadius
            color: Qt.rgba(0, 0, 0, 0.28)
        }
        Rectangle {
            anchors.fill: parent
            radius: work.winRadius
            color: Ui.alpha(root.c("surfaceContainerLow"), root.glass ? 0.84 : 1)
            border.width: work.border
            border.color: win.focused ? root.borderColor(root.v("compositor.activeBorderColor", ["primary"]), "primary") : root.borderColor(root.v("compositor.inactiveBorderColor", ["surface"]), "surface")

            Column {
                x: 12 * root.u + work.border
                y: 12 * root.u + work.border
                width: parent.width - 2 * x
                spacing: 8 * root.u
                Rectangle {
                    width: parent.width * 0.45
                    height: 9 * root.u
                    radius: height / 2
                    color: root.c("overBackground")
                    opacity: 0.85
                }
                Repeater {
                    model: win.lines
                    Rectangle {
                        required property int index
                        width: parent.width * (0.9 - (index % 3) * 0.17)
                        height: 6 * root.u
                        radius: height / 2
                        color: root.c("overSurfaceVariant")
                        opacity: 0.45
                    }
                }
                Row {
                    visible: win.focused
                    spacing: 6 * root.u
                    Rectangle {
                        width: 46 * root.u
                        height: 16 * root.u
                        radius: Math.min(height / 2, root.radius)
                        color: root.c("primary")
                    }
                    Rectangle {
                        width: 34 * root.u
                        height: 16 * root.u
                        radius: Math.min(height / 2, root.radius)
                        color: root.c("secondaryContainer")
                    }
                }
            }
        }
    }

    // Chrome: frame + attached bar, with rounded inner corners.
    Rectangle {
        readonly property real b: Math.max(root.insetTop, root.insetBottom, root.insetLeft, root.insetRight) + 2
        visible: root.frame || (!root.usePanels && (!root.islands || root.contained))
        x: root.insetLeft - b
        y: root.insetTop - b
        width: root.width - root.insetLeft - root.insetRight + 2 * b
        height: root.height - root.insetTop - root.insetBottom + 2 * b
        radius: (root.frame || root.v("theme.enableCorners", true) ? root.radius : 0) + b
        color: "transparent"
        border.width: b
        border.color: root.chrome
    }

    // Bar contents (on the chrome, or floating islands)
    MiniPanels {
        id: miniPanels
        x: root.frameThick
        y: root.frameThick
        width: root.width - 2 * root.frameThick
        height: root.height - 2 * root.frameThick
        visible: root.usePanels
        panels: root.panels
        unit: root.barThick * 0.72
        chrome: root.chrome
        ink: root.c("overBackground")
        line: Ui.alpha(root.c("outlineVariant"), 0.5)
    }

    Item {
        id: bar
        visible: !root.usePanels
        readonly property real m: root.islands && !root.contained ? root.gapOut : 0
        readonly property real along: root.frameThick + m
        x: root.edge === "left" ? m : (root.edge === "right" ? root.width - root.barThick - m : along)
        y: root.edge === "top" ? m : (root.edge === "bottom" ? root.height - root.barThick - m : along)
        width: root.vertical ? root.barThick : root.width - 2 * along
        height: root.vertical ? root.height - 2 * along : root.barThick

        // Islands: three floating groups
        Repeater {
            model: root.islands ? 3 : 0
            Rectangle {
                required property int index
                readonly property real len: [0.26, 0.16, 0.2][index] * (root.vertical ? bar.height : bar.width)
                readonly property real pos: index === 0 ? 0 : (index === 1 ? ((root.vertical ? bar.height : bar.width) - len) / 2 : (root.vertical ? bar.height : bar.width) - len)
                x: root.vertical ? 4 * root.u : pos
                y: root.vertical ? pos : 4 * root.u
                width: root.vertical ? bar.width - 8 * root.u : len
                height: root.vertical ? len : bar.height - 8 * root.u
                radius: Math.min(root.radius, Math.min(width, height) / 2)
                color: root.contained ? Ui.alpha(root.c("surfaceContainer"), 0.9) : root.chrome
            }
        }

        // Workspaces
        Grid {
            id: ws
            readonly property string style: root.v("workspaces.numeralStyle", "arabic")
            readonly property var glyphs: style === "roman" ? ["I", "II", "III", "IV"] : (style === "kanji" ? ["一", "二", "三", "四"] : ["1", "2", "3", "4"])
            columns: root.vertical ? 1 : 4
            spacing: 6 * root.u
            x: root.vertical ? (bar.width - width) / 2 : 14 * root.u
            y: root.vertical ? 14 * root.u : (bar.height - height) / 2
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: index === 0 && !root.vertical ? 30 * root.u : 18 * root.u
                    height: index === 0 && root.vertical ? 30 * root.u : 18 * root.u
                    radius: Math.min(root.radius, height / 2)
                    color: index === 0 ? root.c("primary") : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: ws.glyphs[parent.index]
                        font.family: root.v("theme.font", "")
                        font.pixelSize: 11 * root.u
                        font.weight: Font.Bold
                        color: parent.index === 0 ? root.c("overPrimary") : root.c("overSurfaceVariant")
                    }
                }
            }
        }

        // Integrated dock apps
        Row {
            visible: root.dockOn && root.dockTheme === "integrated" && !root.vertical
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: bar.width * 0.18
            spacing: 5 * root.u
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 18 * root.u
                    height: width
                    radius: Math.min(root.radius * 0.6, width / 2)
                    color: [root.c("primary"), root.c("tertiary"), root.c("secondary"), root.c("primaryContainer")][index]
                }
            }
        }

        // Clock
        Text {
            visible: !root.vertical
            anchors.right: parent.right
            anchors.rightMargin: 16 * root.u
            anchors.verticalCenter: parent.verticalCenter
            text: "21:47"
            font.family: root.v("theme.font", "")
            font.pixelSize: 15 * root.u
            font.weight: Font.DemiBold
            color: root.c("overBackground")
        }
        Rectangle {
            visible: root.vertical
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14 * root.u
            width: 18 * root.u
            height: 18 * root.u
            radius: width / 2
            color: root.c("primary")
        }
    }

    // Notch
    Rectangle {
        visible: !root.v("notch.keepHidden", false)
        readonly property bool island: root.v("notch.theme", "default") === "island"
        readonly property bool atBottom: root.v("notch.position", "top") === "bottom"
        readonly property real edgeY: atBottom ? root.height - root.insetBottom : root.insetTop
        width: root.width * 0.2
        height: 30 * root.u
        x: (root.width - width) / 2
        y: island ? (atBottom ? edgeY - height - root.gapOut : edgeY + root.gapOut) : (atBottom ? root.height - height : 0)
        radius: island ? Math.min(root.radius + 4 * root.u, height / 2) : Math.min(root.radius, height / 2)
        color: root.c("background")
        border.width: island ? Math.max(1, root.u) : 0
        border.color: Ui.alpha(root.c("outlineVariant"), 0.6)
        // Attached notch: square on the screen edge.
        Rectangle {
            visible: !parent.island
            width: parent.width
            height: parent.radius
            y: parent.atBottom ? parent.height - height : 0
            color: parent.color
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.32
            height: 6 * root.u
            radius: height / 2
            color: root.c("overBackground")
            opacity: 0.6
        }
    }

    // Dock (attached or floating)
    Rectangle {
        id: dock
        readonly property bool floating: root.dockTheme === "floating"
        readonly property bool vert: root.dockEdge === "left" || root.dockEdge === "right"
        readonly property real thick: root.v("dock.height", 48) * root.u
        readonly property real gap: floating ? root.gapOut + 2 * root.u : 0
        readonly property real len: 5 * (root.v("dock.iconSize", 24) * root.u * 1.3 + 6 * root.u) + 12 * root.u
        visible: root.dockOn && root.dockTheme !== "integrated"
        width: vert ? thick : len
        height: vert ? len : thick
        x: vert ? (root.dockEdge === "left" ? root.insetLeft + gap : root.width - root.insetRight - thick - gap) : (root.width - width) / 2
        y: vert ? (root.height - height) / 2 : (root.dockEdge === "top" ? root.insetTop + gap : root.height - root.insetBottom - thick - gap)
        radius: Math.min(root.radius + 2 * root.u, Math.min(width, height) / 2)
        color: root.chrome
        border.width: floating ? Math.max(1, root.u) : 0
        border.color: Ui.alpha(root.c("outlineVariant"), 0.5)

        Grid {
            anchors.centerIn: parent
            columns: dock.vert ? 1 : 5
            spacing: 6 * root.u
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: root.v("dock.iconSize", 24) * root.u * 1.3
                    height: width
                    radius: Math.min(root.radius * 0.6, width / 2)
                    color: [root.c("primary"), root.c("tertiary"), root.c("secondary"), root.c("primaryContainer"), root.c("tertiaryContainer")][index]
                }
            }
        }
    }
}
