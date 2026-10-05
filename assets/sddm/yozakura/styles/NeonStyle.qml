import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "../ClockText.js" as ClockText

// Neon / Neon Tokyo (modules/lockscreen/styles/NeonStyle.qml): OLED black,
// thin clock digits lit like a neon tube in one accent (the palette's primary
// hue at full saturation), everything else quiet grey. Dark only.
SddmStyle {
    id: skin

    readonly property real hue: pal.primary.hslHue < 0 ? 0.88 : pal.primary.hslHue
    readonly property color neon: Qt.hsla(hue, 1, 0.62, 1)
    readonly property color core: Qt.hsla(hue, 1, 0.86, 1)
    readonly property bool glows: !greeter.softwareRendering

    ink: Qt.hsla(hue, 0.08, 0.86, 1)
    inkSoft: Qt.hsla(hue, 0.06, 0.55, 1)
    accent: neon
    overAccent: pal.black
    error: Qt.hsla(pal.error.hslHue < 0 ? 0 : pal.error.hslHue, 1, 0.62, 1)

    chipSurface: pal.black
    chipFill: "transparent"
    chipBorder: alpha(neon, 0.28)
    chipInk: inkSoft
    chipCaps: true
    chipLetterSpacing: 2
    menuFill: alpha(pal.black, 0.94)

    arrangement: "stack"
    wallpaperOpacity: 0
    wallpaperBlur: 0
    clock: clockColumn
    cluster: login
    passwordField: input

    backdrop: Item {
        id: night
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: skin.pal.black
        }
        // Faint haze of the sign.
        Shape {
            anchors.fill: parent
            visible: skin.glows
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: night.width / 2
                    centerY: night.height * (skin.greeter.atTop ? 0.62 : 0.4)
                    centerRadius: night.width * 0.45
                    focalX: centerX
                    focalY: centerY
                    GradientStop {
                        position: 0
                        color: skin.alpha(skin.neon, 0.09)
                    }
                    GradientStop {
                        position: 1
                        color: skin.alpha(skin.neon, 0)
                    }
                }
                PathRectangle {
                    width: night.width
                    height: night.height
                }
            }
        }
    }

    Column {
        id: clockColumn
        readonly property real digitSize: Math.round(Math.min(skin.height * 0.22, skin.width * 0.16))
        spacing: Math.round(digitSize * 0.02)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockText.hours(skin.greeter.now, skin.greeter.use12h) + ":" + ClockText.minutes(skin.greeter.now)
            color: skin.glows ? skin.core : skin.neon
            font.family: skin.font
            font.pixelSize: clockColumn.digitSize
            font.weight: Font.ExtraLight
            font.variableAxes: ({
                    "wght": 200
                })
            font.features: ({
                    "tnum": 1
                })
            renderType: Text.QtRendering
            layer.enabled: skin.glows
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.neon
                shadowOpacity: 0.95
                shadowBlur: 1
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 48
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.greeter.now.toLocaleDateString(Qt.locale(), "dddd  d MMMM").toUpperCase()
            color: skin.inkSoft
            font.family: skin.font
            font.pixelSize: Math.max(14, Math.round(clockColumn.digitSize * 0.085))
            font.weight: Font.Medium
            font.letterSpacing: Math.round(clockColumn.digitSize * 0.03)
        }
    }

    Item {
        id: login
        readonly property color tube: skin.errorShown ? skin.error : skin.neon
        width: 400
        height: 48 + 14 + hintText.height

        Item {
            id: line
            width: parent.width
            height: 48
            transform: Translate {
                x: skin.shakeOffset
            }

            Text {
                id: lead
                anchors.left: parent.left
                anchors.verticalCenter: input.verticalCenter
                text: skin.greeter.capsLock ? skin.greeter.iconCapsLock : skin.greeter.iconLock
                font.family: skin.greeter.iconFont
                font.pixelSize: 16
                color: skin.greeter.capsLock ? skin.neon : skin.inkSoft
            }
            TextField {
                id: input
                anchors.left: lead.right
                anchors.leftMargin: 14
                anchors.right: submit.left
                anchors.rightMargin: 14
                anchors.bottom: tubeLine.top
                anchors.bottomMargin: 10
                background: null
                padding: 0
                echoMode: TextInput.Password
                passwordCharacter: "•"
                readOnly: skin.greeter.authenticating
                color: skin.ink
                selectionColor: skin.neon
                selectedTextColor: skin.pal.black
                font.family: skin.font
                font.pixelSize: skin.hasText ? skin.greeter.fontSize + 5 : skin.greeter.fontSize + 1
                font.letterSpacing: skin.hasText ? 5 : 3
                font.capitalization: skin.hasText ? Font.MixedCase : Font.AllUppercase
                placeholderText: "Password"
                placeholderTextColor: skin.inkSoft
                focus: true
                onAccepted: skin.submit()
                onTextChanged: skin.edited()
                Keys.onEscapePressed: skin.cancel()
            }
            Text {
                id: submit
                anchors.right: parent.right
                anchors.verticalCenter: input.verticalCenter
                text: skin.greeter.authenticating ? skin.greeter.iconSpinner : skin.greeter.iconKeyReturn
                font.family: skin.greeter.iconFont
                font.pixelSize: 18
                color: skin.hasText ? skin.neon : skin.inkSoft
                RotationAnimator on rotation {
                    running: skin.greeter.authenticating
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
                onTextChanged: if (!skin.greeter.authenticating)
                    rotation = 0
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    enabled: skin.hasText && !skin.greeter.authenticating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: skin.submit()
                }
            }
            // The tube: dim until focused, lit (with glow) while typing.
            Rectangle {
                id: tubeLine
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                radius: 1
                color: login.tube
                opacity: input.activeFocus || skin.errorShown ? 1 : 0.35
                layer.enabled: skin.glows && (input.activeFocus || skin.errorShown)
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: login.tube
                    shadowOpacity: 0.95
                    shadowBlur: 1
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 48
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: skin.greeter.animDuration
                    }
                }
            }
        }
        Text {
            id: hintText
            anchors.top: line.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.hint.toUpperCase()
            height: Math.max(implicitHeight, skin.greeter.fontSize + 4)
            color: skin.errorShown ? skin.error : skin.neon
            font.family: skin.font
            font.pixelSize: skin.greeter.fontSize - 2
            font.letterSpacing: 2.5
            opacity: skin.hint !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: skin.greeter.animDuration
                }
            }
        }
    }
}
