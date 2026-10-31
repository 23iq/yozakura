pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import "SunPosition.js" as Sun
import "LightModel.js" as Model
import "VisualLanguage.js" as VisualLanguage

// One light source for every shell surface (theme.lighting): the theme
// shadow's direction, length and softness, a lit top edge and the cursor
// lantern. Consumers read the effective shadow here instead of
// Config.theme.shadow* (Shadow, ShadowCaster, CornerMask); with mode "off"
// every value is the theme's own, exactly.
//
// Low frequency: the sun is recomputed by a timer every few minutes (only
// while the sun or the night lantern needs it); nothing here runs per frame.
// The place comes from WeatherService (it writes latitude / longitude once
// the weather location is resolved), a "lat,lon" weather.location, or the
// timezone (SunPosition.fromTimezone).
QtObject {
    id: root

    readonly property var cfg: Config.theme ? Config.theme.lighting : null
    readonly property string mode: Model.normalizeMode(root.cfg ? root.cfg.mode : "off")
    readonly property string lantern: root.cfg ? (root.cfg.lantern || "off") : "off"
    readonly property real angle: root.cfg ? root.cfg.angle : -35
    // theme.lighting.strength: subtle | normal | dramatic, scales everything
    readonly property real scale: Model.strengthScale(root.cfg ? root.cfg.strength : "normal")
    readonly property bool active: root.mode !== "off"

    // Set by WeatherService when it knows the coordinates (NaN = unknown)
    property real latitude: NaN
    property real longitude: NaN
    // Fixed moment for previews / renders (epoch ms; 0 = now)
    property real overrideTime: 0

    readonly property bool needsSun: root.mode === "sun" || root.lantern === "night"
    property real now: Date.now()
    readonly property real moment: root.overrideTime > 0 ? root.overrideTime : root.now

    property Timer clock: Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.needsSun && root.overrideTime <= 0
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    readonly property var place: Sun.resolvePlace(root.latitude, root.longitude, Config.weather ? Config.weather.location : "", new Date(root.moment).getTimezoneOffset())
    readonly property var sun: root.needsSun ? Sun.position(root.moment, root.place.lat, root.place.lon) : null
    readonly property bool night: root.sun !== null && root.sun.altitude < Model.NIGHT_ALTITUDE

    // The light, scaled by the strength: null when off
    readonly property var light: {
        if (root.mode === "fixed")
            return Model.withStrength(Model.fixed(root.angle), root.scale);
        if (root.mode === "sun" && root.sun)
            return Model.withStrength(Model.sun(root.sun.azimuth, root.sun.altitude, root.place.lat), root.scale);
        return null;
    }

    // Effective theme shadow
    readonly property var _base: ({
            x: Config.theme.shadowXOffset,
            y: Config.theme.shadowYOffset,
            blur: Config.theme.shadowBlur,
            opacity: Config.theme.shadowOpacity
        })
    // Lit shadows keep this many px of offset even over a centred theme
    // shadow (6 px at cozy density; x3.4 at golden hour)
    readonly property int minLength: Math.round(Metrics.spacing * 0.75)
    readonly property var _shadow: root.light ? Model.shadow(root.light, root._base, root.minLength) : null
    readonly property int shadowXOffset: root._shadow ? root._shadow.x : Config.theme.shadowXOffset
    readonly property int shadowYOffset: root._shadow ? root._shadow.y : Config.theme.shadowYOffset
    readonly property real shadowBlur: root._shadow ? root._shadow.blur : Config.theme.shadowBlur
    readonly property real shadowOpacity: root._shadow ? root._shadow.opacity : Config.theme.shadowOpacity

    // Warmth tints the shadow, the lit edge and the sun wash with palette
    // roles: a warm mix (tertiary into secondary) at golden hour, the
    // primary accent at night.
    readonly property real warmth: root.light ? root.light.warmth : 0
    readonly property real tintAmount: Math.abs(root.warmth)

    function _mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a);
    }

    // The light colour: the lighter of the text and background roles
    readonly property color _fg: Qt.color(Config.resolveColor("overBackground"))
    readonly property color _bg: Qt.color(Config.resolveColor("background"))
    readonly property color _ink: root._fg.hslLightness >= root._bg.hslLightness ? root._fg : root._bg
    readonly property color _warm: root._mix(Qt.color(Config.resolveColor("tertiary")), Qt.color(Config.resolveColor("secondary")), 0.3)
    readonly property color _cool: Qt.color(Config.resolveColor("primary"))
    readonly property color _tint: root.warmth >= 0 ? root._warm : root._cool
    readonly property color _themeShadow: Qt.color(Config.resolveColor(Config.theme.shadowColor))
    // Shadow colour (alpha = the theme colour's own)
    readonly property color shadowColor: root.light ? root._mix(root._themeShadow, Qt.darker(root._tint, 2.2), 0.45 * root.tintAmount) : root._themeShadow

    // Per-language strengths (VisualLanguage light): edge, wash, dim, lantern
    readonly property var _spec: VisualLanguage.kit(Config.theme.language).light
    readonly property real _day: root.light ? root.light.day : 1

    // Lit edge of surface roots (LitSurface): the top edge peaks where the
    // light stands (edgeCenter 0..1) and the sun-facing side edge
    // (edgeSide -1 left, 1 right, 0 none) catches it while the light is low.
    readonly property real edgeStrength: root.light ? Math.min(1, root._spec.edge * root.scale * (0.5 + 0.5 * root._day)) : 0
    readonly property real edgeCenter: root.light ? 0.5 + 0.42 * root.light.side : 0.5
    readonly property real edgeSide: root.light ? root.light.side : 0
    readonly property color edgeColor: root._mix(root._ink, root._tint, 0.55 * root.tintAmount)

    // Sun wash: one gradient over each surface's background from the lit
    // side, warm at golden hour, a faint white at noon.
    // At night a faint cool moonlight from above instead.
    readonly property real washStrength: root.light ? Math.min(0.42, root._spec.wash * root.scale * (root._day * (0.45 + 0.55 * Math.max(0, root.warmth)) + (1 - root._day) * 0.4)) : 0
    readonly property color washColor: root.warmth >= 0 ? root._mix(root._ink, root._warm, Math.min(1, 1.2 * root.warmth)) : root._mix(root._ink, root._cool, 0.75)
    // Night: surfaces a little dimmer, cool
    readonly property real dimStrength: root.light ? Math.min(0.4, root._spec.dim * root.scale * (1 - root._day)) : 0
    readonly property color dimColor: root._mix(Qt.rgba(0, 0, 0, 1), Qt.darker(root._cool, 2.5), 0.6)

    // Cursor lantern over shell surfaces
    readonly property bool lanternOn: Model.lanternOn(root.lantern, root.night)
    readonly property real lanternStrength: Math.min(0.55, root._spec.lantern * Math.sqrt(root.scale))
    // Falloff radius as a multiple of Space.controlXL (LanternGlow)
    readonly property real lanternReach: 1 + 0.25 * root.scale
    readonly property color lanternColor: root._mix(root._ink, root._warm, 0.35)
}
