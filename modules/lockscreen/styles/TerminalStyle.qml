pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.lockscreen
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.config

// Terminal (CRT): a console login. Monospace phosphor text, a `login:`
// prompt with a blinking block cursor, a tmux-like status bar; light
// scanlines only on the shell surfaces (status bar, login and media boxes).
// Dark tone: phosphor on black glass; light tone: ink on paper-white.
LockStyle {
    id: skin

    readonly property color screen: light ? Qt.lighter(Colors.secondaryFixed, 1.08) : Qt.tint(Colors.shadow, alpha(Colors.primaryFixedDim, 0.05))
    readonly property string mono: Config.theme.monoFont
    readonly property int monoSize: Config.theme.monoFontSize ?? 14
    readonly property real boxRadius: Math.min(Config.roundness, 6)

    ink: light ? Colors.overPrimaryFixed : Colors.primaryFixed
    inkSoft: light ? Colors.overPrimaryFixedVariant : alpha(Colors.primaryFixedDim, 0.72)
    accent: light ? Colors.overTertiaryFixedVariant : Colors.tertiaryFixedDim
    overAccent: screen
    font: mono

    arrangement: "column"
    clusterWidth: 560
    clusterSpacing: 16
    wallpaperBlur: 1
    wallpaperSaturation: -0.6
    wallpaperZoom: 1.02

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
                color: skin.alpha(skin.ink, skin.light ? 0.05 : 0.045)
            }
        }
    }

    // Box with a hairline border, scanlines and a title cut into the top edge.
    component Box: Rectangle {
        id: box
        property string title: ""
        color: skin.alpha(skin.screen, skin.light ? 0.82 : 0.72)
        border.color: skin.alpha(skin.ink, 0.42)
        border.width: 1
        radius: skin.boxRadius

        Scanlines {
            anchors.fill: parent
            anchors.margins: 1
        }
        Rectangle {
            visible: box.title !== ""
            x: 14
            y: -height / 2
            width: titleText.implicitWidth + 12
            height: titleText.implicitHeight
            color: skin.screen

            Text {
                id: titleText
                anchors.centerIn: parent
                text: box.title
                color: skin.inkSoft
                font.family: skin.mono
                font.pixelSize: skin.monoSize - 1
            }
        }
    }

    component Mono: Text {
        color: skin.ink
        font.family: skin.mono
        font.pixelSize: skin.monoSize
        textFormat: Text.PlainText
    }

    function clockTime(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "--:--";
        var s = Math.floor(seconds);
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }

    backdrop: Component {
        Item {
            id: tube

            Rectangle {
                anchors.fill: parent
                color: skin.alpha(skin.screen, 0.9)
            }
            // Tube vignette.
            Shape {
                anchors.fill: parent
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
                            color: skin.light ? skin.alpha(skin.ink, 0.12) : skin.alpha(Colors.shadow, 0.8)
                        }
                    }
                    startX: 0
                    startY: 0
                    PathLine {
                        x: tube.width
                        y: 0
                    }
                    PathLine {
                        x: tube.width
                        y: tube.height
                    }
                    PathLine {
                        x: 0
                        y: tube.height
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }
        }
    }

    // `$ date` and its output: the time in big phosphor digits.
    clock: Component {
        Column {
            id: clockColumn
            readonly property real digitSize: Math.round(Math.min(skin.view.height * 0.17, skin.view.width * 0.1))
            spacing: 4

            Mono {
                text: "$ date +%R"
                color: skin.inkSoft
            }
            Mono {
                id: time
                text: Qt.formatTime(skin.view.now, (Config.bar?.use12hFormat ?? false) ? "h:mm AP" : "HH:mm")
                font.pixelSize: clockColumn.digitSize
                font.weight: Font.Bold
                layer.enabled: !skin.light
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
                text: skin.view.now.toLocaleDateString(Qt.locale(), "dddd dd MMMM yyyy")
                color: skin.inkSoft
                font.pixelSize: skin.monoSize + 2
            }
        }
    }

    passwordField: Component {
        LockPasswordBase {
            id: pw
            field: input
            shakeAmplitude: 0.5
            implicitHeight: box.height

            Box {
                id: box
                width: parent.width
                height: lines.implicitHeight + 36
                title: Brand.displayName.toLowerCase() + " · tty1"
                border.color: pw.errorShown ? skin.error : (input.activeFocus ? skin.alpha(skin.ink, 0.7) : skin.alpha(skin.ink, 0.42))
                transform: Translate {
                    x: pw.shakeOffset
                }

                Column {
                    id: lines
                    x: 18
                    y: 20
                    width: parent.width - 36
                    spacing: 6

                    Mono {
                        text: (skin.view.hostname || "localhost") + " login: " + skin.view.username
                    }
                    Row {
                        width: parent.width
                        Mono {
                            id: prompt
                            text: I18n.t("lockscreen.password") + ": "
                        }
                        TextField {
                            id: input
                            width: parent.width - prompt.width
                            height: prompt.height
                            background: null
                            padding: 0
                            echoMode: TextInput.Password
                            passwordCharacter: "*"
                            enabled: !pw.authenticating
                            color: skin.ink
                            selectionColor: skin.ink
                            selectedTextColor: skin.screen
                            font.family: skin.mono
                            font.pixelSize: skin.monoSize
                            Keys.onReleased: event => pw.observeKey(event)
                            // Drawn below instead (hollow while unfocused).
                            cursorDelegate: Item {}

                            // Block cursor: solid and blinking with focus,
                            // a hollow box like an unfocused terminal without.
                            Rectangle {
                                id: blockCursor
                                x: input.cursorRectangle.x
                                width: cursorMetrics.advanceWidth
                                height: input.height
                                color: input.activeFocus ? skin.ink : "transparent"
                                border.color: skin.ink
                                border.width: 1
                                visible: !pw.authenticating

                                TextMetrics {
                                    id: cursorMetrics
                                    font: input.font
                                    text: "M"
                                }
                                property bool blinkOn: true
                                opacity: blinkOn || !input.activeFocus ? 1 : 0
                                Timer {
                                    interval: 530
                                    repeat: true
                                    running: input.activeFocus && skin.view.startAnim
                                    onRunningChanged: blockCursor.blinkOn = true
                                    onTriggered: blockCursor.blinkOn = !blockCursor.blinkOn
                                }
                            }
                        }
                    }
                    Mono {
                        text: pw.hint === "" ? " " : (pw.errorShown ? "[!] " : "[*] ") + pw.hint
                        color: pw.errorShown ? skin.error : skin.accent
                        opacity: pw.hint !== "" ? 1 : 0
                    }
                }
            }
        }
    }

    mediaCard: Component {
        LockMediaBase {
            id: media
            readonly property int cells: 28
            readonly property int filled: Math.round(progress * cells)
            implicitHeight: mediaBox.height

            Box {
                id: mediaBox
                width: parent.width
                height: mediaLines.implicitHeight + 32
                title: I18n.t("lockscreen.now_playing").toLowerCase()

                Column {
                    id: mediaLines
                    x: 18
                    y: 18
                    width: parent.width - 36
                    spacing: 6

                    Row {
                        width: parent.width
                        Mono {
                            width: parent.width - controls.width
                            text: "♪ " + media.title + (media.artist !== "" ? " — " + media.artist : "")
                            elide: Text.ElideRight
                        }
                        Row {
                            id: controls
                            spacing: 6
                            Repeater {
                                model: [
                                    {
                                        "label": "[<<]",
                                        "act": "previous"
                                    },
                                    {
                                        "label": media.playing ? "[||]" : "[>]",
                                        "act": "toggle"
                                    },
                                    {
                                        "label": "[>>]",
                                        "act": "next"
                                    }
                                ]
                                delegate: Mono {
                                    required property var modelData
                                    text: modelData.label
                                    color: area.containsMouse ? skin.accent : skin.ink
                                    MouseArea {
                                        id: area
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: media[parent.modelData.act]()
                                    }
                                }
                            }
                        }
                    }
                    Mono {
                        visible: media.length > 0
                        text: "[" + "#".repeat(media.filled) + ".".repeat(media.cells - media.filled) + "] " + skin.clockTime(media.position) + " / " + skin.clockTime(media.length)
                        color: skin.inkSoft
                    }
                    NotchVisualizer {
                        width: parent.width
                        height: 18
                        barCount: 48
                        spacing: 3
                        centered: false
                        idleOpacity: 0.3
                        visible: media.visualizerEnabled && CavaService.available
                        configEnabled: media.visualizerEnabled
                        startColor: skin.ink
                        endColor: skin.ink
                        playing: media.playing
                        shown: media.visualizerShown
                    }
                }
            }
        }
    }

    // tmux-like status bar.
    status: Component {
        Rectangle {
            implicitHeight: 30
            color: skin.alpha(skin.ink, skin.light ? 0.08 : 0.07)
            border.color: skin.alpha(skin.ink, 0.28)
            border.width: 1
            radius: skin.boxRadius

            LockStatusInfo {
                id: info
            }
            Scanlines {
                anchors.fill: parent
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: session.implicitWidth + 16
                    height: 22
                    radius: Math.max(0, skin.boxRadius - 2)
                    color: skin.ink
                    Mono {
                        id: session
                        anchors.centerIn: parent
                        text: "[0] " + Brand.appId
                        color: skin.screen
                        font.weight: Font.Bold
                    }
                }
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: skin.view.username + "@" + (skin.view.hostname || "localhost") + "  1:locked*"
                }
            }

            Mono {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: [info.networkLabel !== "" ? "net " + info.networkLabel : I18n.t("lockscreen.offline").toLowerCase(), info.batteryAvailable ? "bat " + info.batteryPercent + "%" : "", Qt.formatTime(skin.view.now, "HH:mm")].filter(s => s !== "").join("  │  ")
                color: info.batteryLow ? skin.error : skin.ink
            }
        }
    }
}
