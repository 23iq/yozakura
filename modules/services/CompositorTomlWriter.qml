pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import "CompositorAppearance.js" as Appearance
import qs.modules.bar.panels
import "../../config/CoreBinds.js" as CoreBinds
import "../specials/Specials.js" as Specials
import "DisplayModel.js" as DisplayModel
import "WriteGate.js" as WriteGate

/**
 * CompositorTomlWriter - Thin IPC client.
 *
 * Renders ~/.local/share/yozakura/<daemon>.toml by delegating to the
 * compositor service in the yozakura backend. The TOML generation logic,
 * the KeybindActions catalog and all keybind resolution live in
 * `backend/pkg/svc/compositor/` (see compositor.Render, compositor.ResolveAction).
 *
 * This singleton only:
 *   1. Assembles the input JSON from Config + Theme + GlobalStates.
 *   2. Calls "compositor.write" on the daemon.
 *   3. Re-fires the call whenever one of the upstream signals changes.
 */
Singleton {
    id: root

    property string outputPath: Brand.dataDir + "/" + Brand.daemon + ".toml"

    property Process ipcProcess: Process {
        stdout: SplitParser {}
        onExited: code => root._onWriteExited(code)
    }

    // Writes are coalesced: a preset load or a slider drag changes many
    // compositor keys in a burst, and each write spawns the yozakura CLI and
    // makes yozd regenerate + reload the compositor config. A write that
    // arrives while one is in flight is queued instead of dropped (Process
    // ignores `running = true` while running, which lost the newest payload).
    property bool _writeQueued: false
    property Timer writeDebounce: Timer {
        interval: 120
        onTriggered: root._flushWrite()
    }

    function getColorValue(colorName) {
        const resolved = Config.resolveColor(colorName);
        return (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
    }

    function getBarOrientation() {
        const position = Panels.primaryEdge;
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    // Fallback values mirror the JsonAdapter defaults in Config.qml so
    // the TOML always has usable color names even if Config.compositor
    // hasn't loaded yet when gatherInput() is called. Without these,
    // undefined var values are dropped by JSON.stringify, leaving the
    // border section empty in the generated hyprland.{lua,conf}.
    function colorOr(arr, fallback) {
        if (Array.isArray(arr) && arr.length > 0) return arr;
        return fallback;
    }
    function intOr(val, fallback) {
        return (val === undefined || val === null) ? fallback : val;
    }
    function boolOr(val, fallback) {
        return (val === undefined || val === null) ? fallback : val;
    }

    // Builds the hl.config() table (general + decoration) from Config.
    // CompositorConfig dispatches this object live and gatherInput()
    // persists it, so what Hyprland gets after a reload is exactly what
    // the shell applied live (gradients, shadow colors, all blur keys).
    function buildHyprlandConfig() {
        return Appearance.buildHyprlandConfig({
            compositor: Config.compositor,
            resolve: getColorValue,
            borderSize: Config.compositorBorderSize,
            rounding: Config.compositorRounding,
            borderColor: Config.compositorBorderColor,
            shadowColor: Config.compositorShadowColor,
            shadowOpacity: Config.compositorShadowOpacity,
            layout: GlobalStates.compositorLayout,
            glass: Glass.compositor
        });
    }

    function gatherInput() {
        // Resolved border color/opacity, matching the QML aliases defined
        // in Config.qml:3476-3480. These aliases already collapse the
        // sync-* toggles onto the appropriate source (theme vs. compositor
        // vs. active list), so reading them here keeps the persisted
        // TOML in lock-step with the live dispatch in CompositorConfig.qml.
        // Using the raw c.rounding / c.borderSize / c.shadowColor would
        // skip the sync logic and let the watcher-driven hyprland.lua
        // regen diverge from the live hl.config() value — e.g. changing
        // a border color would briefly reset the corners to the raw
        // compositor.rounding before the dispatch re-applied the synced
        // theme value.
        const c = Config.compositor;
        const borderSize = Config.compositorBorderSize;
        const rounding = Config.compositorRounding;
        const hl = buildHyprlandConfig();
        const activeBorder = hl.general.col.active_border;
        const inactiveBorder = hl.general.col.inactive_border;
        const shadow = hl.decoration.shadow;
        // Blur strength and shadow range are glass-effective (Glass.qml).
        const blur = hl.decoration.blur;
        // The yozd TOML schema only carries a subset of these values
        // (gradient string for the active border, a single inactive color,
        // the shadow color); the backend renders the full `hyprland`
        // object into the generated hyprland.{lua,conf} on top of it.
        const activeColors = (typeof activeBorder === "string") ? [activeBorder] : activeBorder.colors;

        console.log("CompositorTomlWriter:gatherInput", JSON.stringify({
            activeBorder: activeBorder,
            inactiveBorder: inactiveBorder,
            shadowColor: shadow.color,
            borderSize: borderSize,
            rounding: rounding,
        }));

        return {
            compositor: {
                gapsIn: intOr(c.gapsIn, 0),
                gapsOut: intOr(c.gapsOut, 0),
                borderSize: intOr(borderSize, 2),
                rounding: rounding,
                syncBorderColor: false,
                borderColor: Appearance.firstColor(activeBorder),
                activeBorderColor: activeColors,
                activeBorderAngle: intOr(c.borderAngle, 45),
                inactiveBorderColor: [Appearance.firstColor(inactiveBorder)],
                inactiveBorderAngle: intOr(c.inactiveBorderAngle, 45),
                shadow: {
                    enabled: boolOr(c.shadowEnabled, true),
                    range: intOr(shadow.range, 8),
                    renderPower: intOr(c.shadowRenderPower, 3),
                    sharp: boolOr(c.shadowSharp, false),
                    ignoreWindow: boolOr(c.shadowIgnoreWindow, true),
                    // Already resolved and multiplied by the shadow opacity.
                    color: shadow.color,
                    colorInactive: shadow.color_inactive,
                    opacity: c.shadowOpacity !== undefined ? c.shadowOpacity : 0.5,
                    offset: c.shadowOffset || "0 0",
                    scale: c.shadowScale !== undefined ? c.shadowScale : 1.0,
                },
                blur: {
                    enabled: boolOr(blur.enabled, true),
                    size: intOr(blur.size, 4),
                    passes: intOr(blur.passes, 2),
                    ignoreOpacity: boolOr(c.blurIgnoreOpacity, true),
                    explicitIgnoreAlpha: boolOr(c.blurExplicitIgnoreAlpha, false),
                    ignoreAlphaValue: c.blurIgnoreAlphaValue !== undefined ? c.blurIgnoreAlphaValue : 0.2,
                    newOptimizations: boolOr(c.blurNewOptimizations, true),
                    xray: boolOr(c.blurXray, false),
                    noise: blur.noise,
                    contrast: blur.contrast,
                    brightness: blur.brightness,
                    vibrancy: blur.vibrancy,
                    vibrancyDarkness: c.blurVibrancyDarkness !== undefined ? c.blurVibrancyDarkness : 0.0,
                    special: boolOr(c.blurSpecial, true),
                    popups: boolOr(c.blurPopups, false),
                    popupsIgnorealpha: c.blurPopupsIgnorealpha !== undefined ? c.blurPopupsIgnorealpha : 0.2,
                    inputMethods: boolOr(c.blurInputMethods, false),
                    inputMethodsIgnorealpha: c.blurInputMethodsIgnorealpha !== undefined ? c.blurInputMethodsIgnorealpha : 0.2,
                },
                animations: {
                    enabled: true,
                    // yozd threads this through to the workspace
                    // animation style in hyprland.{lua,conf}. The slide
                    // runs parallel to the bar so workspaces swap in the
                    // same axis the bar occupies:
                    //   bar at top/bottom (horizontal) → slidefade
                    //   bar at left/right (vertical)    → slidefadevert
                    workspaceStyle: (Panels.primaryEdge === "left" || Panels.primaryEdge === "right")
                        ? "slidefadevert 20%"
                        : "slidefade 20%",
                },
            },
            theme: {
                srBarBgOpacity: (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0,
                srBgOpacity: (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Glass.variantOpacity("bg", Config.theme.srBg.opacity, "") : 1.0,
                // false only when glass is switched off: no blur behind shell layers.
                glassShellBlur: Glass.shellBlur,
                shadowColor: Config.theme.shadowColor,
                shadowOpacity: Config.theme.shadowOpacity,
            },
            bar: {
                position: Panels.primaryEdge,
            },
            layout: GlobalStates.compositorLayout,
            keybinds: gatherKeybinds(),
            hyprland: hl,
            // Motion profile (curves + animations) and the smart gaps rule:
            // rendered by the backend after the appearance table.
            motion: CompositorMotion.spec,
            smartGaps: !!c.smartGaps,
            // Special workspaces: apps with "always open here" rules.
            // Saved monitor layout (keyed by current connectors) and keyboard
            // layouts/repeat: rendered as [[monitors]] and the input section.
            displays: root.displayList(),
            keyboard: root.keyboardOn() ? KeyboardService.input() : null,
            windowRules: root.specialsOn() ? Specials.windowRules(Config.specials.workspaces) : [],
        };
    }

    function gatherKeybinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter) {
            console.log("CompositorTomlWriter:gatherKeybinds NO ADAPTER");
            return { yozakura: {}, system: {}, custom: [] };
        }

        const toAction = (a) => a ? { id: a.id, args: a.args || {} } : null;

        // Core binds (config/CoreBinds.js); a bind switched off in the
        // editor is listed in `disabled` and left out here.
        const appRoot = adapter[Brand.appId] || {};
        const disabled = adapter.disabled ? Array.from(adapter.disabled) : [];
        const yozakura = {};
        const system = {};
        for (const entry of CoreBinds.BINDS) {
            const bind = CoreBinds.lookup(appRoot, entry);
            if (!bind || disabled.indexOf(CoreBinds.path(entry)) !== -1)
                continue;
            (entry.section === "system" ? system : yozakura)[entry.name] = {
                modifiers: bind.modifiers || [],
                key: bind.key || "",
                action: toAction(bind.action),
            };
        }

        // Quickshell's JsonAdapter exposes list<var> as a QVariantList, which
        // is iterable and has .length but fails Array.isArray(). Coerce to a
        // real JS array so JSON.stringify preserves the entries and the
        // Go compositor service sees the custom binds in the payload.
        let custom = [];
        if (adapter.custom !== null && adapter.custom !== undefined) {
            try {
                custom = Array.from(adapter.custom);
            } catch (e) {
                custom = [];
            }
        }
        // Special workspace binds live in specials.json (global like
        // binds.json) and are rendered as extra custom binds.
        if (root.specialsOn())
            custom = custom.concat(Specials.compositorBinds(Config.specials.workspaces));
        console.log("CompositorTomlWriter:gatherKeybinds", JSON.stringify({
            hasAdapter: !!adapter,
            yozakuraKeys: Object.keys(yozakura),
            systemKeys: Object.keys(system),
            customLen: custom.length,
        }));
        return {
            yozakura: yozakura,
            system: system,
            custom: custom,
        };
    }

    // Fallback writer used when the yozakura daemon is unreachable.
    // Reproduces the [target] block the Go service produces so the
    // yozd watcher still finds a valid TOML during daemon restarts
    // or when the IPC socket is stale. The QML previously had the
    // full generator in-tree; this is a deliberately minimal subset
    // covering the [target] section only — enough to keep the chain
    // alive, not enough to compete with the Go service.
    property Process fallbackProcess: Process {
        stdout: SplitParser {}
    }

    function fallbackWrite() {
        // The Go service writes relative paths so the wiring follows
        // the TOML directory. The minimal fallback reproduces the
        // same hyprland target line so yozd at least resolves a
        // valid path during the outage.
        const content = "[target]\nhyprland = \"hyprland.lua\"\n";
        fallbackProcess.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "toml-fallback", root.outputPath, content];
        fallbackProcess.running = true;
        console.warn("CompositorTomlWriter: daemon unreachable, wrote fallback [target] only");
    }

    // A pending (unconfirmed) display change must not be undone by a rewrite
    // of the saved layout: writes wait until the session leaves pending.
    property var _gate: WriteGate.create()

    function callWrite() {
        if (!WriteGate.request(root._gate, DisplaysService.pending))
            return;
        writeDebounce.restart();
    }

    function _onWriteExited(code) {
        if (code !== 0) {
            console.warn("CompositorTomlWriter: daemon call failed, using fallback");
            fallbackWrite();
        }
        if (_writeQueued)
            _flushWrite();
    }

    function _flushWrite() {
        if (!WriteGate.request(root._gate, DisplaysService.pending))
            return;
        // Dry run: the CLI call below bypasses BackendService's interception.
        // Journaled only for changes made in the wizard (not the start-up write).
        if (DryRun.active) {
            if (OnboardingService.visible)
                DryRun.journal("write the compositor config");
            return;
        }
        if (ipcProcess.running) {
            _writeQueued = true;
            return;
        }
        _writeQueued = false;
        const input = gatherInput();
        root._lastDisplays = JSON.stringify(input.displays);
        const payload = JSON.stringify(input);
        // The daemon exposes a unix socket; Quickshell.Io.Process doesn't
        // speak the JSON-RPC framing directly, so we run the yozakura CLI
        // with a transient request. If the daemon is down (e.g. socket
        // file is stale), the CLI exits with code 1; we then fall back
        // to a minimal direct write so yozd still has a valid TOML
        // to watch and the rest of the shell keeps working.
        ipcProcess.command = [Brand.appId, "ipc", "call", "compositor.write", payload];
        ipcProcess.running = true;
        console.log("CompositorTomlWriter: requested compositor.write via yozakura CLI");
    }

    // Tracks whether the QML's keybind adapter is ready. We hold the
    // initial TOML regen until both the daemon's compositor service
    // and the binds.json adapter are populated, so the very first
    // write doesn't go out with an empty keybinds block.
    //
    // Important: the keybinds loader runs a 1s createKeybindsTimer +
    // 0.5s repairKeybindsTimer before binds.json is fully populated.
    // adapter.yozakura may exist early (we'd consider it "ready")
    // while adapter.custom is still empty. So readiness must require
    // Config.keybindsInitialLoadComplete AND a non-empty custom list,
    // otherwise the first write silently drops the 98 custom binds.
    property bool configReady: false
    property bool keybindsReady: false

    Component.onCompleted: {
        configReady = !!Config.loader.loaded;
        keybindsReady = _computeKeybindsReady();
        if (configReady && keybindsReady) {
            callWrite();
        } else {
            tomlDeferTimer.start();
            tomlTimeoutTimer.start();
        }
    }

    function _computeKeybindsReady() {
        const a = Config.keybindsLoader.adapter;
        if (!a) return false;
        if (!Config.keybindsInitialLoadComplete) return false;
        // The adapter must have populated the keybinds tree, including
        // the custom list. Without checking custom we can fire a
        // premature write that drops all user keybinds. Quickshell's
        // list<var> arrives as a QVariantList which fails Array.isArray(),
        // so check length-bearing iterability instead.
        const hasCustom = a.custom !== null && a.custom !== undefined && typeof a.custom.length === "number";
        return !!(a.yozakura && hasCustom);
    }

    function _onReady() {
        configReady = !!Config.loader.loaded;
        keybindsReady = _computeKeybindsReady();
        if (configReady && keybindsReady) {
            tomlDeferTimer.stop();
            tomlTimeoutTimer.stop();
            callWrite();
        }
    }

    Timer {
        id: tomlDeferTimer
        interval: 3000
        running: false
        repeat: true
        onTriggered: _onReady()
    }

    Timer {
        id: tomlTimeoutTimer
        interval: 6000
        running: false
        repeat: false
        onTriggered: {
            console.warn("CompositorTomlWriter: config or keybinds not ready after 6s, writing with available data");
            callWrite();
        }
    }

    // Match the previous QML signal set so we don't lose regen triggers.
    property Connections configConnections: Connections {
        target: Config.loader
        function onLoaded() {
            root._onReady();
        }
    }

    property Connections keybindsConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() {
            root._onReady();
        }
        function onFileChanged() { root.callWrite(); }
        function onAdapterUpdated() {
            // adapter.custom may arrive in a separate onAdapterUpdated
            // tick after yozakura. Re-check readiness and fire if it's
            // the first time we see a non-empty custom list.
            root._onReady();
        }
        function onPathChanged() { root.callWrite(); }
    }

    // Config.qml flips keybindsInitialLoadComplete to true once the
    // repair migration has run. Subscribe so the deferred first write
    // happens right after the keybinds are fully populated, not on a
    // 6s timer that may race the migration.
    property Connections keybindsReadyConnection: Connections {
        target: Config
        function onKeybindsInitialLoadCompleteChanged() {
            root._onReady();
        }
    }

    function specialsOn() {
        return Config.specialsReady && Config.specials.enabled;
    }

    function displayList() {
        if (!Config.displaysReady)
            return [];
        return DisplayModel.renderList(Array.from(Config.displays.monitors), DisplaysService.outputs);
    }

    // Hotplug can rename connectors, but every output refresh (also the one
    // after a not yet confirmed change) must not rewrite the compositor
    // config: only a different rendered list does.
    property string _lastDisplays: ""
    function _onOutputsChanged() {
        if (JSON.stringify(root.displayList()) === root._lastDisplays)
            return;
        root.callWrite();
    }

    function keyboardOn() {
        return Config.keyboardReady;
    }

    property Connections displaysConnections: Connections {
        target: Config.displaysReady ? Config.displays : null
        function onMonitorsChanged() { root.callWrite(); }
    }

    property Connections pendingConnections: Connections {
        target: DisplaysService
        function onPendingChanged() {
            if (WriteGate.release(root._gate, DisplaysService.pending))
                root.callWrite();
        }
    }

    property Connections outputsConnections: Connections {
        target: DisplaysService
        function onOutputsChanged() { root._onOutputsChanged(); }
    }

    property Connections keyboardConnections: Connections {
        target: Config.keyboardReady ? Config.keyboard : null
        function onLayoutsChanged() { root.callWrite(); }
        function onSwitchBindChanged() { root.callWrite(); }
        function onOptionsChanged() { root.callWrite(); }
        function onRepeatRateChanged() { root.callWrite(); }
        function onRepeatDelayChanged() { root.callWrite(); }
    }

    property Connections specialsConnections: Connections {
        target: Config.specials
        function onWorkspacesChanged() { root.callWrite(); }
        function onEnabledChanged() { root.callWrite(); }
    }

    property Connections compositorConnections: Connections {
        target: Config.compositor
        function onBorderSizeChanged() { root.callWrite(); }
        function onRoundingChanged() { root.callWrite(); }
        function onGapsInChanged() { root.callWrite(); }
        function onGapsOutChanged() { root.callWrite(); }
        function onActiveBorderColorChanged() { root.callWrite(); }
        function onInactiveBorderColorChanged() { root.callWrite(); }
        function onBorderAngleChanged() { root.callWrite(); }
        function onInactiveBorderAngleChanged() { root.callWrite(); }
        function onSyncRoundnessChanged() { root.callWrite(); }
        function onSyncBorderWidthChanged() { root.callWrite(); }
        function onSyncBorderColorChanged() { root.callWrite(); }
        function onSyncShadowOpacityChanged() { root.callWrite(); }
        function onSyncShadowColorChanged() { root.callWrite(); }
        function onShadowEnabledChanged() { root.callWrite(); }
        function onShadowRangeChanged() { root.callWrite(); }
        function onShadowRenderPowerChanged() { root.callWrite(); }
        function onShadowSharpChanged() { root.callWrite(); }
        function onShadowIgnoreWindowChanged() { root.callWrite(); }
        function onShadowColorChanged() { root.callWrite(); }
        function onShadowColorInactiveChanged() { root.callWrite(); }
        function onShadowOpacityChanged() { root.callWrite(); }
        function onShadowOffsetChanged() { root.callWrite(); }
        function onShadowScaleChanged() { root.callWrite(); }
        function onBlurEnabledChanged() { root.callWrite(); }
        function onBlurSizeChanged() { root.callWrite(); }
        function onBlurPassesChanged() { root.callWrite(); }
        function onBlurIgnoreOpacityChanged() { root.callWrite(); }
        function onBlurExplicitIgnoreAlphaChanged() { root.callWrite(); }
        function onBlurIgnoreAlphaValueChanged() { root.callWrite(); }
        function onBlurNewOptimizationsChanged() { root.callWrite(); }
        function onBlurXrayChanged() { root.callWrite(); }
        function onBlurNoiseChanged() { root.callWrite(); }
        function onBlurContrastChanged() { root.callWrite(); }
        function onBlurBrightnessChanged() { root.callWrite(); }
        function onBlurVibrancyChanged() { root.callWrite(); }
        function onBlurVibrancyDarknessChanged() { root.callWrite(); }
        function onBlurSpecialChanged() { root.callWrite(); }
        function onBlurPopupsChanged() { root.callWrite(); }
        function onBlurPopupsIgnorealphaChanged() { root.callWrite(); }
        function onBlurInputMethodsChanged() { root.callWrite(); }
        function onBlurInputMethodsIgnorealphaChanged() { root.callWrite(); }
        function onSmartGapsChanged() { root.callWrite(); }
        function onDimInactiveChanged() { root.callWrite(); }
        function onDimStrengthChanged() { root.callWrite(); }
    }

    property Connections motionConnections: Connections {
        target: CompositorMotion
        function onSpecChanged() { root.callWrite(); }
    }

    property Connections themeConnections: Connections {
        target: Config.theme
        function onSrBarBgChanged() { root.callWrite(); }
        function onSrBgChanged() { root.callWrite(); }
        function onShadowColorChanged() { root.callWrite(); }
        function onShadowOpacityChanged() { root.callWrite(); }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() { root.callWrite(); }
    }

    property Connections glassConnections: Connections {
        target: Glass
        function onCompositorChanged() { root.callWrite(); }
        function onShellBlurChanged() { root.callWrite(); }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() { root.callWrite(); }
    }
}
