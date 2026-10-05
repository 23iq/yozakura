import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.config
import qs.modules.theme
import qs.modules.bar
import qs.modules.globals
import "CompositorAppearance.js" as Appearance
import "YozdOutput.js" as YozdOutput
import qs.modules.bar.panels

QtObject {
    id: root

    property Process compositorProcess: Process {}

    property var currentAnimationConfig: null
    property Process readAnimationsProcess: Process {
        command: Brand.daemonArgs(["config", "get-animations"])
        stdout: StdioCollector {
            onStreamFinished: {
                const result = YozdOutput.parse(text);
                if (!result.ok) {
                    console.warn("CompositorConfig: could not read animations from " + Brand.daemon + ":", result.error);
                    return;
                }
                // yozd config get-animations returns [animations, beziers]
                if (Array.isArray(result.value) && result.value.length > 0)
                    root.currentAnimationConfig = result.value;
            }
        }
    }

    property var barInstances: []

    function registerBar(barInstance) {
        barInstances.push(barInstance);
    }

    function getBarOrientation() {
        if (barInstances.length > 0) {
            return barInstances[0].orientation || "horizontal";
        }
        const position = Panels.primaryEdge;
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    property Timer applyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: applyCompositorConfigInternal()
    }

    // Built by CompositorTomlWriter so the live dispatch and the persisted
    // hyprland.{lua,conf} come from the very same object.
    function buildHyprlandConfig() {
        return CompositorTomlWriter.buildHyprlandConfig();
    }

    function luaLiteral(value) {
        return Appearance.luaLiteral(value);
    }

    function applyCompositorConfig() {
        readAnimationsProcess.running = true;
        applyTimer.restart();
    }

    function applyCompositorConfigInternal() {
        // Ensure adapters are loaded before applying config.
        if (!Config.loader.loaded) {
            console.log("CompositorConfig: Esperando que se cargue Config...");
            return;
        }

        // Wait for layout to be ready.
        if (!GlobalStates.compositorLayoutReady) {
            console.log("CompositorConfig: Esperando que se detecte el layout de YozdService...");
            return;
        }

        // While GameMode is active the compositor runs the gamemode
        // overrides; persist the user's edit through the TOML path but
        // leave the live state untouched so the mode is not torn down
        // mid-session. On exit the values are restored from config.
        if (GameModeClient.toggled) {
            CompositorTomlWriter.callWrite();
            return;
        }

        const hlConfig = buildHyprlandConfig();

        // Hyprland's hl.config() replaces the given top-level tables, so we
        // only include sections that have meaningful changes. To keep behaviour
        // simple and predictable we always send general + decoration; layer
        // rules + animations + animations are persisted via the TOML path
        // below, since hl.layer_rule / hl.animation are handle-returning
        // builder calls that don't fit the table-replace model.
        const luaExpression = "hl.config(" + luaLiteral(hlConfig) + ")";

        // Live dispatch through the yozakura backend so the change reaches
        // Hyprland immediately, independent of the fsnotify watcher in
        // yozd. The backend shells out via `yozd config raw-batch
        // "eval hl.config({...})"`; the TOML write below is the
        // persistence leg of the round-trip — the watcher regenerates
        // hyprland.{lua,conf} once it detects the new TOML contents.
        BackendService.notify("compositor.eval", { expression: luaExpression });

        // Persist by regenerating the TOML so the new values survive a
        // shell restart and any unrelated compositor change picks them up
        // via the watcher (when that path works).
        CompositorTomlWriter.callWrite();
        root.applySmartGaps();
    }

    // Applies the GameMode appearance overrides live through the same
    // eval path as applyCompositorConfigInternal. Single-statement eval:
    // the [[BATCH]] pipeline splits on ';', so no second Lua statement
    // can ride along. The persisted leg goes through the TOML (the Go
    // renderer injects the same overrides server-side); borderangle is
    // covered by animations being disabled globally.
    function applyGameModeLive() {
        const luaExpression = "hl.config(" + luaLiteral({
            animations: {
                enabled: false,
            },
            decoration: {
                shadow: { enabled: false },
                blur: { enabled: false },
                active_opacity: 1.0,
                inactive_opacity: 1.0,
                fullscreen_opacity: 1.0,
                rounding: 0,
            },
            general: {
                gaps_in: 0,
                gaps_out: 0,
                border_size: 1,
            },
        }) + ")";

        BackendService.notify("compositor.eval", { expression: luaExpression });

        // Regenerate the TOML so the overrides persist and any watcher
        // regen stays consistent with the live dispatch.
        CompositorTomlWriter.callWrite();
    }

    property Connections gameModeConnections: Connections {
        target: GameModeClient
        function onToggledChanged() {
            if (GameModeClient.toggled) {
                applyGameModeLive();
            } else {
                // Restore the user's values live; the TOML regen inside
                // applyCompositorConfigInternal drops the overrides.
                applyCompositorConfig();
            }
        }
    }

    property Connections configConnections: Connections {
        target: Config.loader
        function onFileChanged() {
            applyCompositorConfig();
        }
        function onLoaded() {
            root.syncConfiguredLayout();
            applyCompositorConfig();
        }
    }

    property Connections compositorConfigConnections: Connections {
        target: Config.compositor

        function onBorderSizeChanged() {
            applyCompositorConfig();
        }
        function onRoundingChanged() {
            applyCompositorConfig();
        }
        function onGapsInChanged() {
            applyCompositorConfig();
        }
        function onGapsOutChanged() {
            applyCompositorConfig();
        }
        function onActiveBorderColorChanged() {
            applyCompositorConfig();
        }
        function onInactiveBorderColorChanged() {
            applyCompositorConfig();
        }
        function onBorderAngleChanged() {
            applyCompositorConfig();
        }
        function onInactiveBorderAngleChanged() {
            applyCompositorConfig();
        }
        function onSyncRoundnessChanged() {
            applyCompositorConfig();
        }
        function onSyncBorderWidthChanged() {
            applyCompositorConfig();
        }
        function onSyncBorderColorChanged() {
            applyCompositorConfig();
        }
        function onSyncShadowOpacityChanged() {
            applyCompositorConfig();
        }
        function onSyncShadowColorChanged() {
            applyCompositorConfig();
        }
        function onShadowEnabledChanged() {
            applyCompositorConfig();
        }
        function onShadowRangeChanged() {
            applyCompositorConfig();
        }
        function onShadowRenderPowerChanged() {
            applyCompositorConfig();
        }
        function onShadowSharpChanged() {
            applyCompositorConfig();
        }
        function onShadowIgnoreWindowChanged() {
            applyCompositorConfig();
        }
        function onShadowColorChanged() {
            applyCompositorConfig();
        }
        function onShadowColorInactiveChanged() {
            applyCompositorConfig();
        }
        function onShadowOpacityChanged() {
            applyCompositorConfig();
        }
        function onShadowOffsetChanged() {
            applyCompositorConfig();
        }
        function onShadowScaleChanged() {
            applyCompositorConfig();
        }
        function onBlurEnabledChanged() {
            applyCompositorConfig();
        }
        function onBlurSizeChanged() {
            applyCompositorConfig();
        }
        function onBlurPassesChanged() {
            applyCompositorConfig();
        }
        function onBlurIgnoreOpacityChanged() {
            applyCompositorConfig();
        }
        function onBlurExplicitIgnoreAlphaChanged() {
            applyCompositorConfig();
        }
        function onBlurIgnoreAlphaValueChanged() {
            applyCompositorConfig();
        }
        function onBlurNewOptimizationsChanged() {
            applyCompositorConfig();
        }
        function onBlurXrayChanged() {
            applyCompositorConfig();
        }
        function onBlurNoiseChanged() {
            applyCompositorConfig();
        }
        function onBlurContrastChanged() {
            applyCompositorConfig();
        }
        function onBlurBrightnessChanged() {
            applyCompositorConfig();
        }
        function onBlurVibrancyChanged() {
            applyCompositorConfig();
        }
        function onBlurVibrancyDarknessChanged() {
            applyCompositorConfig();
        }
        function onBlurSpecialChanged() {
            applyCompositorConfig();
        }
        function onBlurPopupsChanged() {
            applyCompositorConfig();
        }
        function onBlurPopupsIgnorealphaChanged() {
            applyCompositorConfig();
        }
        function onBlurInputMethodsChanged() {
            applyCompositorConfig();
        }
        function onBlurInputMethodsIgnorealphaChanged() {
            applyCompositorConfig();
        }
        function onDimInactiveChanged() {
            root.applyCompositorConfig();
        }
        function onDimStrengthChanged() {
            root.applyCompositorConfig();
        }
        function onSmartGapsChanged() {
            root.applySmartGaps();
        }
        // The settings page / a preset picks the tiling layout through the
        // config key; the keybind cycle keeps using GlobalStates directly.
        function onLayoutChanged() {
            root.syncConfiguredLayout();
        }
    }

    // Smart gaps is a workspace rule, not an hl.config() value: re-evaluated
    // only when the setting differs from what was applied live.
    property var _smartGapsApplied: undefined
    function applySmartGaps() {
        const enabled = !!Config.compositor.smartGaps;
        if (enabled === root._smartGapsApplied || GameModeClient.toggled)
            return;
        root._smartGapsApplied = enabled;
        BackendService.notify("compositor.eval", {
            expression: Appearance.smartGapsLua(enabled)
        });
    }

    // Instantiates the motion singleton, which applies the profile live.
    readonly property string motionProfile: CompositorMotion.spec.profile

    // Music-reactive active border (idle unless enabled and music plays).
    property BorderPulse borderPulse: BorderPulse {}

    property Connections colorsConnections: Connections {
        target: Colors
        function onFileChanged() {
            applyCompositorConfig();
        }
        function onLoaded() {
            applyCompositorConfig();
        }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() {
            applyCompositorConfig();
        }
    }

    property Connections srBgConnections: Connections {
        target: Config.theme.srBg
        function onOpacityChanged() {
            applyCompositorConfig();
        }
    }

    property Connections glassConnections: Connections {
        target: Glass
        function onCompositorChanged() {
            root.applyCompositorConfig();
        }
    }

    property Connections srBarBgConnections: Connections {
        target: Config.theme.srBarBg
        function onOpacityChanged() {
            applyCompositorConfig();
        }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() {
            applyCompositorConfig();
        }
        function onCompositorLayoutReadyChanged() {
            if (GlobalStates.compositorLayoutReady) {
                root.syncConfiguredLayout();
                applyCompositorConfig();
            }
        }
    }

    // compositor.layout is the source of truth: the compositor starts on its
    // own default (dwindle), so once both the config and the live layout list
    // are known the configured layout is pushed to the compositor.
    function syncConfiguredLayout() {
        const layout = Config.compositor.layout;
        if (!Config.loader.loaded || !GlobalStates.compositorLayoutReady || !layout)
            return;
        if (layout !== GlobalStates.compositorLayout && GlobalStates.availableLayouts.indexOf(layout) !== -1)
            GlobalStates.setCompositorLayout(layout);
    }


    Component.onCompleted: {
        // Apply immediately if Config is already loaded.
        if (Config.loader.loaded) {
            applyCompositorConfig();
        }
        // Otherwise, handled by onLoaded.
    }
}
