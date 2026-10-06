pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ColorUtils.js" as ColorUtils
import "AppThemes.js" as AppThemes
import qs.modules.globals

FileView {
    id: colors
    // QUICKSHELL-GIT: path: Quickshell.cachePath("colors.json")
    path: Brand.cacheDir + "/colors.json"
    preload: true
    watchChanges: true
    onFileChanged: {
        beginPaletteCrossfade();
        reload();
        generationTimer.restart();
    }

    // ── Palette crossfade ────────────────────────────────────────────
    // When colors.json changes, every public role eases from what is on
    // screen now to the new adapter value instead of snapping. A single
    // progress value drives all roles: each binding reads it only while a
    // crossfade runs, so once it ends the roles bind straight to the
    // adapter again with zero ongoing cost. Progress is stepped by a
    // ~60 Hz timer (not the render loop) to bound binding re-evaluation
    // across the shell regardless of monitor refresh rate.
    readonly property var blendedRoles: ["background", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "surfaceDim", "surfaceTint", "surfaceVariant", "blue", "blueContainer", "blueSource", "blueValue", "cyan", "cyanContainer", "cyanSource", "cyanValue", "error", "errorContainer", "green", "greenContainer", "greenSource", "greenValue", "inverseOnSurface", "inversePrimary", "inverseSurface", "lightBlue", "lightCyan", "lightGreen", "lightMagenta", "lightRed", "lightYellow", "magenta", "magentaContainer", "magentaSource", "magentaValue", "overBackground", "overBlue", "overBlueContainer", "overCyan", "overCyanContainer", "overError", "overErrorContainer", "overGreen", "overGreenContainer", "overMagenta", "overMagentaContainer", "overPrimary", "overPrimaryContainer", "overPrimaryFixed", "overPrimaryFixedVariant", "overRed", "overRedContainer", "overSecondary", "overSecondaryContainer", "overSecondaryFixed", "overSecondaryFixedVariant", "overSurface", "overSurfaceVariant", "overTertiary", "overTertiaryContainer", "overTertiaryFixed", "overTertiaryFixedVariant", "overWhite", "overWhiteContainer", "overYellow", "overYellowContainer", "outline", "outlineVariant", "primary", "primaryContainer", "primaryFixed", "primaryFixedDim", "red", "redContainer", "redSource", "redValue", "scrim", "secondary", "secondaryContainer", "secondaryFixed", "secondaryFixedDim", "shadow", "tertiary", "tertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "white", "whiteContainer", "whiteSource", "whiteValue", "yellow", "yellowContainer", "yellowSource", "yellowValue", "sourceColor"]

    property bool _crossfading: false
    property real _blendT: 1
    property var _blendFrom: ({})
    property real _blendStart: 0
    property int _blendDuration: 600

    function _blend(name, target) {
        if (!_crossfading)
            return target;
        const a = _blendFrom[name];
        if (a === undefined)
            return target;
        const t = _blendT;
        return Qt.rgba(a.r + (target.r - a.r) * t, a.g + (target.g - a.g) * t, a.b + (target.b - a.b) * t, a.a + (target.a - a.a) * t);
    }

    function beginPaletteCrossfade() {
        const duration = (Config.theme && Config.theme.paletteTransitionDuration !== undefined) ? Config.theme.paletteTransitionDuration : 600;
        if (duration <= 0 || Config.animDuration <= 0) {
            _crossfading = false;
            crossfadeTimer.stop();
            return;
        }
        // Snapshot what is displayed right now (mid-blend values included,
        // so back-to-back changes stay continuous).
        const from = {};
        for (let i = 0; i < blendedRoles.length; i++) {
            const c = colors[blendedRoles[i]];
            from[blendedRoles[i]] = {
                r: c.r,
                g: c.g,
                b: c.b,
                a: c.a
            };
        }
        _blendFrom = from;
        _blendDuration = duration;
        _blendStart = Date.now();
        _blendT = 0;
        _crossfading = true;
        crossfadeTimer.restart();
    }

    property Timer crossfadeTimer: Timer {
        id: crossfadeTimer
        interval: 16
        repeat: true
        onTriggered: {
            const x = Math.min(1, (Date.now() - colors._blendStart) / colors._blendDuration);
            if (x >= 1) {
                stop();
                colors._crossfading = false;
                colors._blendT = 1;
                colors._blendFrom = ({});
                return;
            }
            // easeInOutCubic
            colors._blendT = x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
        }
    }

    property Connections oledWatcher: Connections {
        target: Config
        function onOledModeChanged() {
            generationTimer.restart();
        }
    }

    property Connections themeWatcher: Connections {
        target: Config.loader
        function onFileChanged() {
            generationTimer.restart();
        }
    }

    // Kitty's background opacity comes from the theme config, not the
    // palette: regenerate (and live-reload kitty) when it changes, e.g. on
    // a preset switch or a settings edit, without waiting for colors.json.
    property Connections terminalOpacityWatcher: Connections {
        target: Config.theme
        function onTerminalOpacityChanged() {
            kittyTimer.restart();
        }
    }

    property Connections glassTerminalWatcher: Connections {
        target: Glass
        function onTerminalOpacityChanged() {
            colors.kittyTimer.restart();
        }
    }

    property Connections srBgOpacityWatcher: Connections {
        target: Config.theme.srBg
        function onOpacityChanged() {
            kittyTimer.restart();
        }
    }

    property Timer kittyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (colors.appThemed("kitty"))
                kittyGenerator.generate(colors);
            // Same opacity/font inputs as kitty.
            for (const id of ["ghostty", "foot", "alacritty"]) {
                if (colors.appThemed(id))
                    colors[id + "Generator"].generate(colors);
            }
        }
    }

    // External app theming (AppThemes.js registry, config apps.theming).
    function appThemed(id) {
        return AppThemes.enabled(Config.apps ? Config.apps.theming : null, id);
    }

    // Settings "regenerate app themes now": every enabled generator, now.
    signal appThemesRegenerated
    function regenerateApps() {
        generationTimer.restart();
    }

    // Re-run when an app is switched back on, and when the kitty font changes.
    readonly property string themingState: Config.apps ? JSON.stringify(AppThemes.generatorsFor(Config.apps.theming)) : ""
    onThemingStateChanged: generationTimer.restart()
    property Connections kittyFontWatcher: Connections {
        target: Config.apps ? Config.apps.kitty : null
        ignoreUnknownSignals: true
        function onFontChanged() {
            colors.kittyTimer.restart();
        }
        function onFontSizeChanged() {
            colors.kittyTimer.restart();
        }
    }

    property QtCtGenerator qtCtGenerator: QtCtGenerator {
        id: qtCtGenerator
    }

    property GtkGenerator gtkGenerator: GtkGenerator {
        id: gtkGenerator
    }

    property PywalGenerator pywalGenerator: PywalGenerator {
        id: pywalGenerator
    }

    property KittyGenerator kittyGenerator: KittyGenerator {
        id: kittyGenerator
    }

    property GhosttyGenerator ghosttyGenerator: GhosttyGenerator {
        id: ghosttyGenerator
    }

    property FootGenerator footGenerator: FootGenerator {
        id: footGenerator
    }

    property AlacrittyGenerator alacrittyGenerator: AlacrittyGenerator {
        id: alacrittyGenerator
    }

    property NvChadGenerator nvChadGenerator: NvChadGenerator {
        id: nvChadGenerator
    }

    property DiscordGenerator discordGenerator: DiscordGenerator {
        id: discordGenerator
    }

    property PywalZenGenerator pywalZenGenerator: PywalZenGenerator {
        id: pywalZenGenerator
    }

    property SddmGenerator sddmGenerator: SddmGenerator {
        id: sddmGenerator
    }

    property SpicetifyGenerator spicetifyGenerator: SpicetifyGenerator {
        id: spicetifyGenerator
    }

    property TelegramGenerator telegramGenerator: TelegramGenerator {
        id: telegramGenerator
    }

    property FirefoxGenerator firefoxGenerator: FirefoxGenerator {
        id: firefoxGenerator
    }

    property PapirusGenerator papirusGenerator: PapirusGenerator {
        id: papirusGenerator
    }

    property NvimGenerator nvimGenerator: NvimGenerator {
        id: nvimGenerator
    }

    property Timer generationTimer: Timer {
        id: generationTimer
        interval: 100
        repeat: false
        onTriggered: {
            // External app themes are written from Colors.*; wait for the
            // crossfade to land so they get the final palette.
            if (colors._crossfading) {
                restart();
                return;
            }
            const names = AppThemes.generatorsFor(Config.apps ? Config.apps.theming : null);
            for (let i = 0; i < names.length; i++) {
                const generator = colors[names[i]];
                if (generator)
                    generator.generate(colors);
            }
            colors.appThemesRegenerated();
        }
    }

    adapter: JsonAdapter {
        property color background: "#1a1111"
        property color blue: "#cebdfe"
        property color blueContainer: "#4c3e76"
        property color blueSource: "#0000ff"
        property color blueValue: "#0000ff"
        property color cyan: "#84d5c4"
        property color cyanContainer: "#005045"
        property color cyanSource: "#00ffff"
        property color cyanValue: "#00ffff"
        property color error: "#ffb4ab"
        property color errorContainer: "#93000a"
        property color green: "#b7d085"
        property color greenContainer: "#3a4d10"
        property color greenSource: "#00ff00"
        property color greenValue: "#00ff00"
        property color inverseOnSurface: "#382e2d"
        property color inversePrimary: "#904a46"
        property color inverseSurface: "#f1dedd"
        property color lightBlue: "#cebdfe"
        property color lightCyan: "#84d5c4"
        property color lightGreen: "#b7d085"
        property color lightMagenta: "#fcb0d5"
        property color lightRed: "#ffb4ab"
        property color lightYellow: "#dec56e"
        property color magenta: "#fcb0d5"
        property color magentaContainer: "#6c3353"
        property color magentaSource: "#ff00ff"
        property color magentaValue: "#ff00ff"
        property color overBackground: "#f1dedd"
        property color overBlue: "#35275e"
        property color overBlueContainer: "#e8ddff"
        property color overCyan: "#00382f"
        property color overCyanContainer: "#9ff2e0"
        property color overError: "#690005"
        property color overErrorContainer: "#ffdad6"
        property color overGreen: "#253600"
        property color overGreenContainer: "#d3ec9e"
        property color overMagenta: "#521d3c"
        property color overMagentaContainer: "#ffd8e8"
        property color overPrimary: "#571d1c"
        property color overPrimaryContainer: "#ffdad7"
        property color overPrimaryFixed: "#3b0809"
        property color overPrimaryFixedVariant: "#733331"
        property color overRed: "#561e19"
        property color overRedContainer: "#ffdad6"
        property color overSecondary: "#442928"
        property color overSecondaryContainer: "#ffdad7"
        property color overSecondaryFixed: "#2c1514"
        property color overSecondaryFixedVariant: "#5d3f3d"
        property color overSurface: "#f1dedd"
        property color overSurfaceVariant: "#d8c2c0"
        property color overTertiary: "#402d04"
        property color overTertiaryContainer: "#ffdea7"
        property color overTertiaryFixed: "#271900"
        property color overTertiaryFixedVariant: "#594319"
        property color overWhite: "#00363d"
        property color overWhiteContainer: "#9eeffd"
        property color overYellow: "#3b2f00"
        property color overYellowContainer: "#fce186"
        property color outline: "#a08c8b"
        property color outlineVariant: "#534342"
        property color primary: "#ffb3ae"
        property color primaryContainer: "#733331"
        property color primaryFixed: "#ffdad7"
        property color primaryFixedDim: "#ffb3ae"
        property color red: "#ffb4ab"
        property color redContainer: "#73332e"
        property color redSource: "#ff0000"
        property color redValue: "#ff0000"
        property color scrim: "#000000"
        property color secondary: "#e7bdb9"
        property color secondaryContainer: "#5d3f3d"
        property color secondaryFixed: "#ffdad7"
        property color secondaryFixedDim: "#e7bdb9"
        property color shadow: "#000000"
        property color surface: "#1a1111"
        property color surfaceBright: "#423736"
        property color surfaceContainer: "#271d1d"
        property color surfaceContainerHigh: "#322827"
        property color surfaceContainerHighest: "#3d3231"
        property color surfaceContainerLow: "#231919"
        property color surfaceContainerLowest: "#140c0c"
        property color surfaceDim: "#1a1111"
        property color surfaceTint: "#ffb3ae"
        property color surfaceVariant: "#534342"
        property color tertiary: "#e2c28c"
        property color tertiaryContainer: "#594319"
        property color tertiaryFixed: "#ffdea7"
        property color tertiaryFixedDim: "#e2c28c"
        property color white: "#82d3e0"
        property color whiteContainer: "#004f58"
        property color whiteSource: "#ffffff"
        property color whiteValue: "#ffffff"
        property color yellow: "#dec56e"
        property color yellowContainer: "#554500"
        property color yellowSource: "#ffff00"
        property color yellowValue: "#ffff00"
        property color sourceColor: "#7f2424"
    }

    property color background: Config.oledMode ? "#000000" : _blend("background", adapter.background)

    readonly property var ansi: ColorUtils.ansiColors(ColorUtils.fromQml(adapter.primary.toString()), ColorUtils.isDark(ColorUtils.fromQml(adapter.background.toString())))

    // Derived from the (blended) public roles so they crossfade with them.
    property color surface: Qt.tint(background, Qt.rgba(overBackground.r, overBackground.g, overBackground.b, 0.1))
    property color surfaceBright: Qt.tint(background, Qt.rgba(overBackground.r, overBackground.g, overBackground.b, 0.2))
    property color surfaceContainer: _blend("surfaceContainer", adapter.surfaceContainer)
    property color surfaceContainerHigh: _blend("surfaceContainerHigh", adapter.surfaceContainerHigh)
    property color surfaceContainerHighest: _blend("surfaceContainerHighest", adapter.surfaceContainerHighest)
    property color surfaceContainerLow: _blend("surfaceContainerLow", adapter.surfaceContainerLow)
    property color surfaceContainerLowest: _blend("surfaceContainerLowest", adapter.surfaceContainerLowest)
    property color surfaceDim: _blend("surfaceDim", adapter.surfaceDim)
    property color surfaceTint: _blend("surfaceTint", adapter.surfaceTint)
    property color surfaceVariant: _blend("surfaceVariant", adapter.surfaceVariant)

    // Direct color properties from adapter
    property color blue: _blend("blue", ansi.blue)
    property color blueContainer: _blend("blueContainer", adapter.blueContainer)
    property color blueSource: _blend("blueSource", adapter.blueSource)
    property color blueValue: _blend("blueValue", adapter.blueValue)
    property color cyan: _blend("cyan", ansi.cyan)
    property color cyanContainer: _blend("cyanContainer", adapter.cyanContainer)
    property color cyanSource: _blend("cyanSource", adapter.cyanSource)
    property color cyanValue: _blend("cyanValue", adapter.cyanValue)
    property color error: _blend("error", adapter.error)
    property color errorContainer: _blend("errorContainer", adapter.errorContainer)
    property color green: _blend("green", ansi.green)
    property color greenContainer: _blend("greenContainer", adapter.greenContainer)
    property color greenSource: _blend("greenSource", adapter.greenSource)
    property color greenValue: _blend("greenValue", adapter.greenValue)
    property color inverseOnSurface: _blend("inverseOnSurface", adapter.inverseOnSurface)
    property color inversePrimary: _blend("inversePrimary", adapter.inversePrimary)
    property color inverseSurface: _blend("inverseSurface", adapter.inverseSurface)
    property color lightBlue: _blend("lightBlue", ansi.lightBlue)
    property color lightCyan: _blend("lightCyan", ansi.lightCyan)
    property color lightGreen: _blend("lightGreen", ansi.lightGreen)
    property color lightMagenta: _blend("lightMagenta", ansi.lightMagenta)
    property color lightRed: _blend("lightRed", ansi.lightRed)
    property color lightYellow: _blend("lightYellow", ansi.lightYellow)
    property color magenta: _blend("magenta", ansi.magenta)
    property color magentaContainer: _blend("magentaContainer", adapter.magentaContainer)
    property color magentaSource: _blend("magentaSource", adapter.magentaSource)
    property color magentaValue: _blend("magentaValue", adapter.magentaValue)
    property color overBackground: _blend("overBackground", adapter.overBackground)
    property color overBlue: _blend("overBlue", adapter.overBlue)
    property color overBlueContainer: _blend("overBlueContainer", adapter.overBlueContainer)
    property color overCyan: _blend("overCyan", adapter.overCyan)
    property color overCyanContainer: _blend("overCyanContainer", adapter.overCyanContainer)
    property color overError: _blend("overError", adapter.overError)
    property color overErrorContainer: _blend("overErrorContainer", adapter.overErrorContainer)
    property color overGreen: _blend("overGreen", adapter.overGreen)
    property color overGreenContainer: _blend("overGreenContainer", adapter.overGreenContainer)
    property color overMagenta: _blend("overMagenta", adapter.overMagenta)
    property color overMagentaContainer: _blend("overMagentaContainer", adapter.overMagentaContainer)
    property color overPrimary: _blend("overPrimary", adapter.overPrimary)
    property color overPrimaryContainer: _blend("overPrimaryContainer", adapter.overPrimaryContainer)
    property color overPrimaryFixed: _blend("overPrimaryFixed", adapter.overPrimaryFixed)
    property color overPrimaryFixedVariant: _blend("overPrimaryFixedVariant", adapter.overPrimaryFixedVariant)
    property color overRed: _blend("overRed", adapter.overRed)
    property color overRedContainer: _blend("overRedContainer", adapter.overRedContainer)
    property color overSecondary: _blend("overSecondary", adapter.overSecondary)
    property color overSecondaryContainer: _blend("overSecondaryContainer", adapter.overSecondaryContainer)
    property color overSecondaryFixed: _blend("overSecondaryFixed", adapter.overSecondaryFixed)
    property color overSecondaryFixedVariant: _blend("overSecondaryFixedVariant", adapter.overSecondaryFixedVariant)
    property color overSurface: _blend("overSurface", adapter.overSurface)
    property color overSurfaceVariant: _blend("overSurfaceVariant", adapter.overSurfaceVariant)
    property color overTertiary: _blend("overTertiary", adapter.overTertiary)
    property color overTertiaryContainer: _blend("overTertiaryContainer", adapter.overTertiaryContainer)
    property color overTertiaryFixed: _blend("overTertiaryFixed", adapter.overTertiaryFixed)
    property color overTertiaryFixedVariant: _blend("overTertiaryFixedVariant", adapter.overTertiaryFixedVariant)
    property color overWhite: _blend("overWhite", adapter.overWhite)
    property color overWhiteContainer: _blend("overWhiteContainer", adapter.overWhiteContainer)
    property color overYellow: _blend("overYellow", adapter.overYellow)
    property color overYellowContainer: _blend("overYellowContainer", adapter.overYellowContainer)
    property color outline: _blend("outline", adapter.outline)
    property color outlineVariant: _blend("outlineVariant", adapter.outlineVariant)
    property color primary: _blend("primary", adapter.primary)
    property color primaryContainer: _blend("primaryContainer", adapter.primaryContainer)
    property color primaryFixed: _blend("primaryFixed", adapter.primaryFixed)
    property color primaryFixedDim: _blend("primaryFixedDim", adapter.primaryFixedDim)
    property color red: _blend("red", ansi.red)
    property color redContainer: _blend("redContainer", adapter.redContainer)
    property color redSource: _blend("redSource", adapter.redSource)
    property color redValue: _blend("redValue", adapter.redValue)
    property color scrim: _blend("scrim", adapter.scrim)
    property color secondary: _blend("secondary", adapter.secondary)
    property color secondaryContainer: _blend("secondaryContainer", adapter.secondaryContainer)
    property color secondaryFixed: _blend("secondaryFixed", adapter.secondaryFixed)
    property color secondaryFixedDim: _blend("secondaryFixedDim", adapter.secondaryFixedDim)
    property color shadow: _blend("shadow", adapter.shadow)
    property color tertiary: _blend("tertiary", adapter.tertiary)
    property color tertiaryContainer: _blend("tertiaryContainer", adapter.tertiaryContainer)
    property color tertiaryFixed: _blend("tertiaryFixed", adapter.tertiaryFixed)
    property color tertiaryFixedDim: _blend("tertiaryFixedDim", adapter.tertiaryFixedDim)
    property color white: _blend("white", adapter.white)
    property color whiteContainer: _blend("whiteContainer", adapter.whiteContainer)
    property color whiteSource: _blend("whiteSource", adapter.whiteSource)
    property color whiteValue: _blend("whiteValue", adapter.whiteValue)
    property color yellow: _blend("yellow", ansi.yellow)
    property color yellowContainer: _blend("yellowContainer", adapter.yellowContainer)
    property color yellowSource: _blend("yellowSource", adapter.yellowSource)
    property color yellowValue: _blend("yellowValue", adapter.yellowValue)
    property color sourceColor: _blend("sourceColor", adapter.sourceColor)

    property color criticalText: "#FF6B08"
    property color criticalRed: "#FF0028"

    // Semantic aliases
    property color warning: yellow
    property color success: green

    // List of available color names for color pickers (excludes internal/source colors)
    readonly property var availableColorNames: ["background", "surface", "surfaceBright", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "surfaceDim", "surfaceTint", "surfaceVariant", "primary", "primaryContainer", "primaryFixed", "primaryFixedDim", "secondary", "secondaryContainer", "secondaryFixed", "secondaryFixedDim", "tertiary", "tertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "error", "errorContainer", "overBackground", "overSurface", "overSurfaceVariant", "overPrimary", "overPrimaryContainer", "overPrimaryFixed", "overPrimaryFixedVariant", "overSecondary", "overSecondaryContainer", "overSecondaryFixed", "overSecondaryFixedVariant", "overTertiary", "overTertiaryContainer", "overTertiaryFixed", "overTertiaryFixedVariant", "overError", "overErrorContainer", "outline", "outlineVariant", "inversePrimary", "inverseSurface", "inverseOnSurface", "shadow", "scrim", "blue", "blueContainer", "overBlue", "overBlueContainer", "lightBlue", "cyan", "cyanContainer", "overCyan", "overCyanContainer", "lightCyan", "green", "greenContainer", "overGreen", "overGreenContainer", "lightGreen", "magenta", "magentaContainer", "overMagenta", "overMagentaContainer", "lightMagenta", "red", "redContainer", "overRed", "overRedContainer", "lightRed", "yellow", "yellowContainer", "overYellow", "overYellowContainer", "lightYellow", "white", "whiteContainer", "overWhite", "overWhiteContainer"]
}
