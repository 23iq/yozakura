import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "../ClockText.js" as ClockText

// Aurora / Glacier (modules/lockscreen/styles/AuroraStyle.qml): the
// wallpaper dissolved behind light frost with soft aurora glows, the date
// over a big rounded clock, the user's picture, name and a frosted capsule.
SddmStyle {
    id: skin

    readonly property color frost: light ? Qt.lighter(pal.secondaryFixed, 1.1) : Qt.tint(pal.black, alpha(pal.secondaryFixed, 0.1))
    readonly property color rim: light ? Qt.lighter(frost, 1.08) : alpha(pal.secondaryFixed, 0.22)
    readonly property real capsule: greeter.roundnessFactor

    accent: light ? pal.overPrimaryFixedVariant : pal.primaryFixedDim

    chipSurface: frost
    chipFill: alpha(frost, light ? 0.55 : 0.5)
    chipBorder: rim
    menuFill: alpha(frost, 0.92)

    arrangement: "center"
    wallpaperBlur: 1
    wallpaperSaturation: 0.15
    wallpaperZoom: 1.1
    clock: clockColumn
    cluster: login
    passwordField: input

    // A soft round glow of the aurora.
    component Glow: Shape {
        id: glow
        property color tint: skin.accent
        property real strength: 0.4
        visible: !skin.greeter.softwareRendering
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.width / 2
                centerY: glow.height / 2
                centerRadius: Math.min(glow.width, glow.height) / 2
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0
                    color: skin.alpha(glow.tint, glow.strength)
                }
                GradientStop {
                    position: 1
                    color: skin.alpha(glow.tint, 0)
                }
            }
            PathRectangle {
                width: glow.width
                height: glow.height
            }
        }
    }

    backdrop: Item {
        id: sky
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: skin.alpha(skin.frost, skin.light ? 0.38 : 0.5)
        }
        Glow {
            x: -sky.width * 0.15
            y: -sky.height * 0.35
            width: sky.width * 0.8
            height: sky.height * 0.9
            tint: skin.light ? skin.pal.primaryFixed : skin.pal.primaryFixedDim
            strength: skin.light ? 0.55 : 0.22
        }
        Glow {
            x: sky.width * 0.45
            y: -sky.height * 0.25
            width: sky.width * 0.75
            height: sky.height * 0.8
            tint: skin.light ? skin.pal.tertiaryFixed : skin.pal.tertiaryFixedDim
            strength: skin.light ? 0.5 : 0.18
        }
        Glow {
            x: sky.width * 0.1
            y: sky.height * 0.55
            width: sky.width * 0.8
            height: sky.height * 0.8
            tint: skin.light ? skin.pal.secondaryFixed : skin.pal.secondaryFixedDim
            strength: skin.light ? 0.45 : 0.12
        }
    }

    // Date above a big rounded clock.
    Column {
        id: clockColumn
        readonly property real digitSize: Math.round(Math.min(skin.height * 0.24, skin.width * 0.17))
        spacing: -Math.round(digitSize * 0.1)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.greeter.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: skin.alpha(skin.ink, 0.85)
            font.family: skin.font
            font.pixelSize: Math.max(16, Math.round(clockColumn.digitSize * 0.12))
            font.weight: Font.DemiBold
            font.variableAxes: ({
                    "wght": 600,
                    "ROND": 100
                })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockText.hours(skin.greeter.now, skin.greeter.use12h) + ":" + ClockText.minutes(skin.greeter.now)
            color: skin.alpha(skin.ink, 0.92)
            font.family: skin.font
            font.pixelSize: clockColumn.digitSize
            font.weight: Font.DemiBold
            font.variableAxes: ({
                    "wght": 620,
                    "ROND": 100
                })
            font.features: ({
                    "tnum": 1
                })
            renderType: Text.QtRendering
            layer.enabled: !skin.greeter.softwareRendering
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.light ? skin.frost : skin.pal.black
                shadowOpacity: skin.light ? 0.7 : 0.5
                shadowBlur: 1
                shadowVerticalOffset: 2
                blurMax: 48
            }
        }
    }

    // Picture, name, frosted capsule, hint.
    Column {
        id: login
        width: 360
        spacing: 12

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            greeter: skin.greeter
            width: 64
            height: 64
            ink: skin.ink
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.greeter.userName
            color: skin.ink
            font.family: skin.font
            font.pixelSize: skin.greeter.fontSize + 3
            font.weight: Font.DemiBold
        }
        Rectangle {
            id: capsuleBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 44
            radius: height / 2 * skin.capsule
            color: skin.alpha(skin.frost, skin.light ? 0.55 : 0.5)
            border.width: 1
            border.color: skin.errorShown ? skin.error : (input.activeFocus ? skin.alpha(skin.accent, 0.7) : skin.rim)
            transform: Translate {
                x: skin.shakeOffset
            }

            TextField {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                background: null
                padding: 0
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                readOnly: skin.greeter.authenticating
                color: skin.ink
                selectionColor: skin.accent
                selectedTextColor: skin.overAccent
                font.family: skin.font
                font.pixelSize: skin.greeter.fontSize
                font.letterSpacing: skin.hasText ? 4 : 0.2
                focus: true
                onAccepted: skin.submit()
                onTextChanged: skin.edited()
                Keys.onEscapePressed: skin.cancel()
            }
            // Centred placeholder (the control hides its own when centred).
            Text {
                anchors.centerIn: parent
                visible: !skin.hasText
                text: "Password"
                color: skin.alpha(skin.ink, 0.5)
                font: input.font
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: skin.greeter.capsLock
                text: skin.greeter.iconCapsLock
                font.family: skin.greeter.iconFont
                font.pixelSize: 15
                color: skin.accent
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16 * skin.capsule
                color: skin.accent
                opacity: skin.hasText || skin.greeter.authenticating ? 1 : 0
                scale: skin.hasText || skin.greeter.authenticating ? 1 : 0.6
                Behavior on opacity {
                    NumberAnimation {
                        duration: skin.greeter.animDuration
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: skin.greeter.animDuration
                        easing.type: Easing.OutBack
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: skin.greeter.authenticating ? skin.greeter.iconSpinner : skin.greeter.iconArrowRight
                    font.family: skin.greeter.iconFont
                    font.pixelSize: 15
                    color: skin.overAccent
                    RotationAnimator on rotation {
                        running: skin.greeter.authenticating
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                    onTextChanged: if (!skin.greeter.authenticating)
                        rotation = 0
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: skin.hasText && !skin.greeter.authenticating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: skin.submit()
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.hint
            height: Math.max(implicitHeight, skin.greeter.fontSize + 5)
            color: skin.errorShown ? skin.error : skin.alpha(skin.ink, 0.8)
            font.family: skin.font
            font.pixelSize: skin.greeter.fontSize - 1
            font.weight: Font.Medium
            opacity: skin.hint !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: skin.greeter.animDuration
                }
            }
        }
    }
}
