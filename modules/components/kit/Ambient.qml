import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit

// A window's atmosphere: the wallpaper (`source`) heavily blurred and
// darkened with a soft vignette, so a whole window carries the desktop's
// colour; surfaces (kit Card) sit over it. Static and cheap: the image is
// decoded tiny (sourceSize) and blurred once into a cached layer - nothing
// is re-rendered per frame, it only redraws when the wallpaper changes
// (then the new one cross-fades in, Motion.glide). How much shows is the
// visual language's `Look.ambientStrength` (glass / ink all of it, the
// solid languages a little around their surfaces). `plain`: no picture at
// all, the theme background only (blur off, battery saver).
Item {
    id: root

    property url source: ""
    property bool plain: false
    // 0..1: how much of the wallpaper shows through the darkening
    property real strength: Look.ambientStrength

    // the theme background under everything (and the plain fallback)
    Mark {
        anchors.fill: parent
        radius: 0
        color: Colors.background
    }

    // two layers so a new wallpaper cross-fades over the old one
    property int front: 0
    onSourceChanged: {
        const next = 1 - root.front;
        (next === 0 ? a : b).source = root.source;
        root.front = next;
    }
    Component.onCompleted: a.source = root.source

    component Blurred: Image {
        id: img
        property bool shown: false
        property bool plain: false
        property real strength: 1
        anchors.fill: parent
        visible: !img.plain && img.opacity > 0
        opacity: img.shown && img.status === Image.Ready ? img.strength : 0
        // decoded tiny: the blur starts soft and costs nothing
        sourceSize.width: 96
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        layer.enabled: img.visible
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.35
        }
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration * 2
                easing.type: Motion.glide.easing
            }
        }
    }
    Blurred {
        id: a
        plain: root.plain
        strength: root.strength
        shown: root.front === 0
    }
    Blurred {
        id: b
        plain: root.plain
        strength: root.strength
        shown: root.front === 1
    }

    // On a light theme the wash is stronger: a dark wallpaper under a
    // light window otherwise turns the whole window mid grey, and the
    // theme's dark-on-light text loses its contrast.
    readonly property bool lightTheme: Colors.background.hslLightness > 0.5
    // wash toward the theme background, more at the edges (a vignette)
    Mark {
        anchors.fill: parent
        radius: 0
        visible: !root.plain
        color: Qt.alpha(Colors.background, root.lightTheme ? 0.74 - 0.2 * root.strength : 0.5 - 0.28 * root.strength)
    }
    Mark {
        anchors.fill: parent
        radius: 0
        visible: !root.plain
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Colors.background, 0.4)
            }
            GradientStop {
                position: 0.35
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Colors.background, 0.65)
            }
        }
    }
    Mark {
        anchors.fill: parent
        radius: 0
        visible: !root.plain
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.alpha(Colors.background, 0.45)
            }
            GradientStop {
                position: 0.25
                color: "transparent"
            }
            GradientStop {
                position: 0.75
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Colors.background, 0.45)
            }
        }
    }
}
