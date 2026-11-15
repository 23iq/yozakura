import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit
import "../../theme/InkContrast.js" as InkContrast

// A window's atmosphere: the wallpaper (`source`) heavily blurred and
// darkened with a soft vignette, so a whole window carries the desktop's
// colour; surfaces (kit Card) sit over it. Static and cheap: the image is
// decoded tiny (sourceSize) and blurred once into a cached layer - nothing
// is re-rendered per frame, it only redraws when the wallpaper changes
// (then the new one cross-fades in, Motion.palette). How much shows is the
// visual language's `Look.ambientStrength` (glass / ink all of it, the
// solid languages a little around their surfaces). `plain`: no picture at
// all, the theme background only (blur off, battery saver).
Item {
    id: root

    property url source: ""
    property bool plain: false
    // 0..1: how much of the wallpaper shows through the darkening
    property real strength: Look.ambientStrength
    // `strength` as drawn: it moves with a page morph (Motion.morph), and the
    // wallpaper and the wash over it follow the same value, so the colour
    // never jumps while the picture fades.
    property real level: root.strength
    Behavior on level {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

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
        anchors.fill: parent
        visible: !img.plain && img.opacity > 0
        opacity: img.shown && img.status === Image.Ready ? 1 : 0
        // decoded very small: no shape of the wallpaper survives (a moon or a
        // flower read as a smudge behind the content), only its colours
        sourceSize.width: 24
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        layer.enabled: img.visible
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.35
            // highlights pressed toward the mid tones: a colour field, no glare
            contrast: -0.45
            brightness: -0.06
        }
        Behavior on opacity {
            enabled: Motion.palette > 0
            NumberAnimation {
                duration: Motion.palette
                easing.type: Motion.micro.easing
            }
        }
    }
    // how much shows: the drawn level over both (the cross-fade is theirs)
    Item {
        anchors.fill: parent
        opacity: root.level
        Blurred {
            id: a
            plain: root.plain
            shown: root.front === 0
        }
        Blurred {
            id: b
            plain: root.plain
            shown: root.front === 1
        }
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
        // (the muted ink's contrast model reads the same wash: InkContrast)
        color: Qt.alpha(Colors.background, InkContrast.ambientWash(root.lightTheme, root.level))
        // a new theme: the wash turns with the palette
        Behavior on color {
            enabled: Motion.palette > 0
            ColorAnimation {
                duration: Motion.palette
            }
        }
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
