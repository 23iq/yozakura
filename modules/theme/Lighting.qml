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

    // The light: null when off
    readonly property var light: {
        if (root.mode === "fixed")
            return Model.fixed(root.angle);
        if (root.mode === "sun" && root.sun)
            return Model.sun(root.sun.azimuth, root.sun.altitude, root.place.lat);
        return null;
    }

    // Effective theme shadow
    readonly property var _base: ({
            x: Config.theme.shadowXOffset,
            y: Config.theme.shadowYOffset,
            blur: Config.theme.shadowBlur,
            opacity: Config.theme.shadowOpacity
        })
    // Lit shadows keep this many px of offset even over a centred theme shadow
    readonly property int minLength: 4
    readonly property var _shadow: root.light ? Model.shadow(root.light, root._base, root.minLength) : null
    readonly property int shadowXOffset: root._shadow ? root._shadow.x : Config.theme.shadowXOffset
    readonly property int shadowYOffset: root._shadow ? root._shadow.y : Config.theme.shadowYOffset
    readonly property real shadowBlur: root._shadow ? root._shadow.blur : Config.theme.shadowBlur
    readonly property real shadowOpacity: root._shadow ? root._shadow.opacity : Config.theme.shadowOpacity

    // Warmth tints the shadow and the lit edge with palette roles: the
    // tertiary accent at golden hour, the primary one at night.
    readonly property real warmth: root.light ? root.light.warmth : 0
    readonly property string tintRole: root.warmth >= 0 ? "tertiary" : "primary"
    readonly property real tintAmount: Math.abs(root.warmth)

    function _mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a);
    }

    readonly property color _tint: Qt.color(Config.resolveColor(root.tintRole))
    readonly property color _themeShadow: Qt.color(Config.resolveColor(Config.theme.shadowColor))
    // Shadow colour (alpha = the theme colour's own)
    readonly property color shadowColor: root.light ? root._mix(root._themeShadow, Qt.darker(root._tint, 2.4), 0.22 * root.tintAmount) : root._themeShadow

    // Lit top edge of surface roots: where along the edge the light peaks
    // (0..1) and how strong it is (VisualLanguage light.edge: 0 in
    // languages without edges).
    readonly property var _spec: VisualLanguage.kit(Config.theme.language).light
    readonly property real edgeStrength: root.light ? root._spec.edge * (0.35 + 0.65 * root.light.day) : 0
    readonly property real edgeCenter: root.light ? 0.5 + 0.38 * root.light.side : 0.5
    readonly property color edgeColor: root._mix(Qt.color(Config.resolveColor("overBackground")), root._tint, 0.35 * root.tintAmount)

    // Cursor lantern over shell surfaces
    readonly property bool lanternOn: Model.lanternOn(root.lantern, root.night)
    readonly property real lanternStrength: root._spec.lantern
    // Radius of the glow: fifteen spacing steps (120 px at cozy density)
    readonly property real lanternRadius: Metrics.spacing * 15
    readonly property color lanternColor: root._mix(Qt.color(Config.resolveColor("overBackground")), Qt.color(Config.resolveColor("tertiary")), 0.3)
}
