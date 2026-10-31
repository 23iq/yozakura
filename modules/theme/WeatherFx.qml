pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import "WeatherFxModel.js" as Model
import "VisualLanguage.js" as VisualLanguage

// Weather on surfaces (theme.weatherFx): which effects the current weather
// asks for, resolved once for the whole shell. StyledRect loads one overlay
// (modules/components/weatherfx/WeatherOverlay.qml) per surface root while
// `active` (or while a preview scope exists); with mode "off" nothing is
// created and nothing here runs.
//
// WeatherService feeds the weather (code, °C) here, Lighting the place; the
// season is re-read twice a day. `previewCondition` forces a condition for
// renders and tests (runtime only, never stored, never reported as weather).
QtObject {
    id: root

    readonly property var opts: Model.options(Config.theme ? Config.theme.weatherFx : null)
    readonly property string mode: root.opts.mode
    readonly property bool enabled: root.mode !== "off"

    // Fed by WeatherService
    property int weatherCode: 0
    property real temperature: NaN
    property bool known: false

    // "" = the live weather; else a WeatherFxModel.PREVIEWS id
    property string previewCondition: ""
    // Preview scopes alive (WeatherFxScope): overlays load while > 0
    property int scopes: 0
    // Fixed seed for renders and tests (0 = random layouts)
    property int seed: 0

    property real now: Date.now()
    property Timer clock: Timer {
        interval: 12 * 3600 * 1000
        repeat: true
        running: root.enabled && root.opts.seasonal
        onTriggered: root.now = Date.now()
    }

    readonly property var liveWeather: ({
            code: root.weatherCode,
            tempC: root.temperature,
            known: root.known,
            month: new Date(root.now).getMonth(),
            lat: Lighting.place ? Lighting.place.lat : NaN
        })

    // The effects every overlay draws (levels 0..1, see WeatherFxModel)
    readonly property var effects: root.previewCondition !== "" ? root.effectsFor(root.previewCondition) : Model.effects(root.opts, root.liveWeather, false)
    readonly property bool active: root.enabled && root.effects.any

    // Effects of a forced condition, at the configured mode (subtle while off)
    function effectsFor(condition: string): var {
        const w = Model.previewWeather(condition);
        if (!w)
            return Model.effects(root.opts, root.liveWeather, false);
        const o = Object.assign({}, root.opts, {
            mode: root.enabled ? root.mode : "subtle"
        });
        return Model.effects(o, w, true);
    }

    // Shell surfaces that carry the weather (desktop widgets and app
    // windows do not)
    function hosts(surface: string): bool {
        return surface === "bar" || surface === "notch" || surface === "dock" || surface === "popups" || surface === "sidebars";
    }

    // Ambient motion: none with motion off or the profile disabled
    readonly property bool motionOn: Motion.base > 0 && !(Config.motionProfile && Config.motionProfile.disabled)
    // Ambient durations follow the shell speed (1 at the default 300 ms)
    readonly property real tempo: Math.max(0.5, Math.min(2, Motion.base / 300))
    function ms(base: real): int {
        return Math.round(base * root.tempo);
    }
    function cadence(kind: string, level: real): int {
        return Model.cadence(kind, level, root.mode === "vivid" ? "vivid" : "subtle");
    }
    function beadCount(level: real, area: real): int {
        return Model.beadCount(level, root.mode === "vivid" ? "vivid" : "subtle", area);
    }
    function flakeSlots(level: real, width: real): int {
        return Model.flakeSlots(level, root.mode === "vivid" ? "vivid" : "subtle", width);
    }
    function rng(salt: int): var {
        return Model.rng(root.seed > 0 ? root.seed * 7919 + salt : Math.floor(Math.random() * 1e9));
    }

    // How the language draws it (VisualLanguage weather spec)
    readonly property var spec: VisualLanguage.kit(Config.theme.language).weather
    readonly property string drop: root.spec.drop
    readonly property real alpha: root.spec.alpha

    // Palette roles: the light catching water and ice (the brightest role
    // of the palette), the side away from it, and the haze of fog.
    readonly property bool _light: !!Config.theme.lightMode
    readonly property color glint: root._light ? Colors.surfaceContainerLowest : Colors.overBackground
    readonly property color shade: Colors.shadow
    // Frost, flake halos and haze: light on a dark surface, a cool grey line on
    // a light one (white on white would vanish)
    readonly property color ice: root._light ? Colors.outline : Colors.overBackground
    readonly property color mist: root.ice
    readonly property color warm: Colors.tertiary
}
