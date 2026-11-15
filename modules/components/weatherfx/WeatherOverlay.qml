pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme

// Weather on one surface root (theme.weatherFx): the single overlay StyledRect
// loads under the surface's content, clipped by its shape. Each effect is a
// Loader that exists only while the weather asks for it; the bar alone gets
// the heat shimmer and the seasonal petal. Effects animate only while
// `animate` (motion on, surface and window shown) and sit still otherwise.
Item {
    id: root

    // The StyledRect surface root (typed loosely: it lives in the parent
    // directory)
    property var surface: null
    // Corner radius of the surface (frost and flakes keep inside it)
    readonly property real radius: root.surface ? root.surface.radius : 0

    // Effects reach past their item (fog banks, a petal arriving): keep them
    // on the surface
    clip: true
    readonly property var fx: WeatherFx.effects
    readonly property string host: root.surface ? root.surface.glassSurface : ""
    readonly property bool isBar: root.host === "bar"
    readonly property bool horizontal: root.width >= root.height
    readonly property real strength: root.fx.strength * WeatherFx.alpha
    readonly property bool shown: root.visible && root.width > 0 && root.height > 0 && root.Window.window !== null && root.Window.window.visible
    // A fullscreen window on this screen covers the shell: the weather rests
    // (the bar reports it through WeatherFx.setCovered)
    readonly property var win: root.Window.window
    readonly property var screen: root.win ? root.win.screen : null
    readonly property bool covered: root.screen ? WeatherFx.coveredScreens[root.screen.name] === true : false
    readonly property bool animate: WeatherFx.motionOn && root.shown && !root.covered
    // Salt of this surface's random layout (stable per host)
    readonly property int salt: root.host.length * 131 + Math.round(root.width) % 97

    Loader {
        objectName: "weatherFog"
        anchors.fill: parent
        active: root.fx.fog > 0
        sourceComponent: FogHaze {
            level: root.fx.fog
            animate: root.animate
            strength: root.strength
            salt: root.salt
            radius: root.radius
        }
    }

    Loader {
        objectName: "weatherFrost"
        anchors.fill: parent
        active: root.fx.frost > 0
        sourceComponent: FrostCorners {
            level: root.fx.frost
            strength: root.strength
            animate: root.animate
            salt: root.salt
            compact: root.isBar
            radius: root.radius
        }
    }

    Loader {
        objectName: "weatherHeat"
        anchors.fill: parent
        active: root.isBar && root.fx.heat > 0
        sourceComponent: HeatShimmer {
            level: root.fx.heat
            strength: root.strength
            animate: root.animate
        }
    }

    Loader {
        objectName: "weatherRain"
        anchors.fill: parent
        active: root.fx.rain > 0
        sourceComponent: RainBeads {
            level: root.fx.rain
            strength: root.strength
            animate: root.animate
            salt: root.salt
            radius: root.radius
        }
    }

    Loader {
        objectName: "weatherSnow"
        anchors.fill: parent
        active: root.fx.snow > 0
        sourceComponent: SnowLine {
            level: root.fx.snow
            strength: root.strength
            animate: root.animate
            salt: root.salt
            radius: root.radius
        }
    }

    Loader {
        objectName: "weatherSeasonal"
        anchors.fill: parent
        active: root.isBar && root.fx.seasonal !== ""
        sourceComponent: SeasonalDrift {
            leaf: root.fx.seasonal === "leaves"
            strength: root.strength
            animate: root.animate
            horizontal: root.horizontal
            salt: root.salt
        }
    }
}
