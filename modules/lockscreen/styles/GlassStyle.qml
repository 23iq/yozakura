pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.lockscreen
import qs.modules.theme

// Glass: the blurred wallpaper under a vignette, a heavy clock with an
// accent colon, glass status chips, media card and password pill. Dark
// tone: black glass; light tone: frosted white glass with dark ink.
LockStyle {
    id: skin

    // Glass fill and the scrim over the wallpaper.
    readonly property color surface: light ? Qt.lighter(Colors.secondaryFixed, 1.08) : Colors.shadow
    readonly property real dim: light ? 0.28 : 0.34

    arrangement: "stack"
    wallpaperBlur: 0.7

    backdrop: Component {
        Item {
            id: shade
            readonly property bool atTop: skin.view.atTop

            // Even dim so bright pastel art never washes out the text.
            Rectangle {
                anchors.fill: parent
                color: skin.alpha(skin.surface, skin.dim)
            }

            // Vignette: clear centre, deep corners.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: shade.width / 2
                        centerY: shade.height * 0.45
                        centerRadius: Math.hypot(shade.width, shade.height) * 0.6
                        focalX: centerX
                        focalY: centerY
                        GradientStop {
                            position: 0.0
                            color: skin.alpha(skin.surface, 0.0)
                        }
                        GradientStop {
                            position: 0.45
                            color: skin.alpha(skin.surface, 0.08)
                        }
                        GradientStop {
                            position: 1.0
                            color: skin.alpha(skin.surface, skin.light ? 0.5 : 0.72)
                        }
                    }
                    startX: 0
                    startY: 0
                    PathLine {
                        x: shade.width
                        y: 0
                    }
                    PathLine {
                        x: shade.width
                        y: shade.height
                    }
                    PathLine {
                        x: 0
                        y: shade.height
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }

            // Deeper floor behind the input/media cluster.
            Rectangle {
                width: parent.width
                height: parent.height * 0.5
                y: shade.atTop ? 0 : parent.height - height
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: skin.alpha(skin.surface, shade.atTop ? 0.55 : 0.0)
                    }
                    GradientStop {
                        position: 1.0
                        color: skin.alpha(skin.surface, shade.atTop ? 0.0 : 0.55)
                    }
                }
            }

            // Light scrim under the status strip.
            Rectangle {
                width: parent.width
                height: Math.min(200, parent.height * 0.2)
                y: shade.atTop ? parent.height - height : 0
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: skin.alpha(skin.surface, shade.atTop ? 0.0 : 0.35)
                    }
                    GradientStop {
                        position: 1.0
                        color: skin.alpha(skin.surface, shade.atTop ? 0.35 : 0.0)
                    }
                }
            }
        }
    }

    clock: Component {
        LockClock {
            pixelSize: Math.round(Math.min(skin.view.height * 0.22, skin.view.width * 0.16))
            now: skin.view.now
            digitColor: skin.ink
            colonColor: skin.accent
            shadowColor: skin.surface
            shadowOpacity: skin.light ? 0.5 : 0.7
        }
    }

    passwordField: Component {
        LockPasswordPill {
            textColor: skin.ink
            accent: skin.accent
            overAccent: skin.overAccent
            errorColor: skin.error
            fill: skin.surface
            fontFamily: skin.font
        }
    }

    mediaCard: Component {
        LockMediaCard {
            textColor: skin.ink
            accent: skin.accent
            overAccent: skin.overAccent
            fill: skin.surface
            spectrumEnd: skin.light ? Colors.overTertiaryFixedVariant : Colors.tertiaryFixedDim
        }
    }

    status: Component {
        LockStatusRow {
            username: skin.view.username
            textColor: skin.ink
            errorColor: skin.error
            fill: skin.surface
        }
    }
}
