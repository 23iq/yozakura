pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// Terminal / CRT (modules/lockscreen/styles/TerminalStyle.qml): a console
// login. Monospace phosphor text, `<host> login:` and a password prompt with
// a blinking block cursor; light scanlines only on the boxes and chips.
SddmStyle {
    id: skin

    readonly property color screen: light ? Qt.lighter(pal.secondaryFixed, 1.08) : Qt.tint(pal.black, alpha(pal.primaryFixedDim, 0.05))
    readonly property string mono: greeter.monoFont
    readonly property int monoSize: greeter.fontSize
    readonly property real boxRadius: Math.min(greeter.roundness, 6)

    ink: light ? pal.overPrimaryFixed : pal.primaryFixed
    inkSoft: light ? pal.overPrimaryFixedVariant : alpha(pal.primaryFixedDim, 0.72)
    accent: light ? pal.overTertiaryFixedVariant : pal.tertiaryFixedDim
    overAccent: screen
    font: mono

    chipSurface: screen
    chipFill: alpha(screen, light ? 0.85 : 0.75)
    chipBorder: alpha(ink, 0.35)
    chipRoundness: Math.min(1, boxRadius / 18)
    menuFill: alpha(screen, 0.95)

    arrangement: "column"
    wallpaperBlur: 1
    wallpaperSaturation: -0.6
    wallpaperZoom: 1.02
    clock: clockColumn
    cluster: loginBox
    passwordField: input
    shakeAmplitude: 0.5

    // Light horizontal scanlines over a surface.
    component Scanlines: Item {
        clip: true
        Repeater {
            model: Math.ceil(parent.height / 3)
            Rectangle {
                required property int index
                y: index * 3
                width: parent.width
                height: 1
                color: skin.alpha(skin.ink, 0.045)
            }
        }
    }

    component Mono: Text {
        color: skin.ink
        font.family: skin.mono
        font.pixelSize: skin.monoSize
        textFormat: Text.PlainText
    }

    backdrop: Item {
        id: tube
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: skin.alpha(skin.screen, 0.9)
        }
        // Tube vignette.
        Shape {
            anchors.fill: parent
            visible: !skin.greeter.softwareRendering
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: tube.width / 2
                    centerY: tube.height / 2
                    centerRadius: Math.hypot(tube.width, tube.height) * 0.62
                    focalX: centerX
                    focalY: centerY
                    GradientStop {
                        position: 0.55
                        color: skin.alpha(skin.screen, 0)
                    }
                    GradientStop {
                        position: 1
                        color: skin.light ? skin.alpha(skin.ink, 0.12) : skin.alpha(skin.pal.black, 0.8)
                    }
                }
                PathRectangle {
                    width: tube.width
                    height: tube.height
                }
            }
        }
    }

    // `$ date` and its output.
    Column {
        id: clockColumn
        readonly property real digitSize: Math.round(Math.min(skin.height * 0.17, skin.width * 0.1))
        spacing: 4

        Mono {
            text: "$ date +%R"
            color: skin.inkSoft
        }
        Mono {
            text: Qt.formatTime(skin.greeter.now, skin.greeter.use12h ? "h:mm AP" : "HH:mm")
            font.pixelSize: clockColumn.digitSize
            font.weight: Font.Bold
            layer.enabled: !skin.light && !skin.greeter.softwareRendering
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.ink
                shadowOpacity: 0.45
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 32
            }
        }
        Mono {
            text: skin.greeter.now.toLocaleDateString(Qt.locale(), "dddd dd MMMM yyyy")
            color: skin.inkSoft
            font.pixelSize: skin.monoSize + 2
        }
    }

    // The login box: title cut into the border, prompts, cursor, hint.
    Rectangle {
        id: loginBox
        width: 560
        height: lines.implicitHeight + 36
        color: skin.alpha(skin.screen, skin.light ? 0.82 : 0.72)
        border.width: 1
        border.color: skin.errorShown ? skin.error : (input.activeFocus ? skin.alpha(skin.ink, 0.7) : skin.alpha(skin.ink, 0.42))
        radius: skin.boxRadius
        transform: Translate {
            x: skin.shakeOffset
        }

        Scanlines {
            anchors.fill: parent
            anchors.margins: 1
        }
        Rectangle {
            x: 14
            y: -height / 2
            width: title.implicitWidth + 12
            height: title.implicitHeight
            color: skin.screen
            Mono {
                id: title
                anchors.centerIn: parent
                text: "sddm · " + (skin.greeter.currentSession ? skin.greeter.currentSession.sName : "tty1")
                color: skin.inkSoft
                font.pixelSize: skin.monoSize - 1
            }
        }

        Column {
            id: lines
            x: 18
            y: 20
            width: parent.width - 36
            spacing: 6

            Mono {
                text: (skin.greeter.hostName || "localhost") + " login: " + skin.greeter.userName
            }
            Row {
                width: parent.width
                Mono {
                    id: prompt
                    text: "Password: "
                }
                TextField {
                    id: input
                    width: parent.width - prompt.width
                    height: prompt.height
                    background: null
                    padding: 0
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    readOnly: skin.greeter.authenticating
                    color: skin.ink
                    selectionColor: skin.ink
                    selectedTextColor: skin.screen
                    font.family: skin.mono
                    font.pixelSize: skin.monoSize
                    focus: true
                    onAccepted: skin.submit()
                    onTextChanged: skin.edited()
                    Keys.onEscapePressed: skin.cancel()
                    cursorDelegate: Rectangle {
                        width: cursorMetrics.advanceWidth
                        height: input.height
                        color: skin.ink
                        visible: input.activeFocus

                        TextMetrics {
                            id: cursorMetrics
                            font: input.font
                            text: "M"
                        }
                        SequentialAnimation on opacity {
                            running: input.activeFocus
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 1
                                duration: 0
                            }
                            PauseAnimation {
                                duration: 530
                            }
                            NumberAnimation {
                                to: 0
                                duration: 0
                            }
                            PauseAnimation {
                                duration: 530
                            }
                        }
                    }
                }
            }
            Mono {
                text: skin.hint === "" ? " " : (skin.errorShown ? "[!] " : "[*] ") + skin.hint
                color: skin.errorShown ? skin.error : skin.accent
                opacity: skin.hint !== "" ? 1 : 0
            }
        }
    }
}
