pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.lockscreen
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.config
import "../../desktop/clockstyles/ClockText.js" as ClockText

// Aurora (Glacier): the wallpaper dissolved behind light frosted glass with
// soft aurora glows, the date over a big rounded clock, and the user's
// picture, name and a frosted capsule in the centre. Light tone: frost and
// dark ink; dark tone: polar night.
LockStyle {
    id: skin

    readonly property color frost: light ? Qt.lighter(Colors.secondaryFixed, 1.1) : Qt.tint(Colors.shadow, alpha(Colors.secondaryFixed, 0.1))
    // Edge highlight of the frosted surfaces.
    readonly property color rim: light ? Qt.lighter(frost, 1.08) : alpha(Colors.secondaryFixed, 0.22)
    readonly property real capsuleRadius: Config.roundness > 0 ? Math.min(1, Config.roundness / 16) : 0

    accent: light ? Colors.overPrimaryFixedVariant : Colors.primaryFixedDim

    arrangement: "center"
    clusterWidth: 360
    clusterSpacing: 20
    wallpaperBlur: 1
    wallpaperSaturation: 0.15
    wallpaperZoom: 1.1

    // Frosted surface: translucent frost, a bright rim and a soft shadow.
    component Frost: Rectangle {
        color: skin.alpha(skin.frost, skin.light ? 0.55 : 0.5)
        border.color: skin.rim
        border.width: 1
        antialiasing: true
    }

    // A soft round glow of the aurora.
    component Glow: Shape {
        id: glow
        property color tint: skin.accent
        property real strength: 0.4
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

    backdrop: Component {
        Item {
            id: sky

            Rectangle {
                anchors.fill: parent
                color: skin.alpha(skin.frost, skin.light ? 0.38 : 0.5)
            }
            Glow {
                x: -sky.width * 0.15
                y: -sky.height * 0.35
                width: sky.width * 0.8
                height: sky.height * 0.9
                tint: skin.light ? Colors.primaryFixed : Colors.primaryFixedDim
                strength: skin.light ? 0.55 : 0.22
            }
            Glow {
                x: sky.width * 0.45
                y: -sky.height * 0.25
                width: sky.width * 0.75
                height: sky.height * 0.8
                tint: skin.light ? Colors.tertiaryFixed : Colors.tertiaryFixedDim
                strength: skin.light ? 0.5 : 0.18
            }
            Glow {
                x: sky.width * 0.1
                y: sky.height * 0.55
                width: sky.width * 0.8
                height: sky.height * 0.8
                tint: skin.light ? Colors.secondaryFixed : Colors.secondaryFixedDim
                strength: skin.light ? 0.45 : 0.12
            }
        }
    }

    // Date above a big rounded clock (wght 600, rounded axis where the
    // theme font has one).
    clock: Component {
        Column {
            id: clockColumn
            readonly property real digitSize: Math.round(Math.min(skin.view.height * 0.24, skin.view.width * 0.17))
            spacing: -Math.round(digitSize * 0.1)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: skin.view.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
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
                text: ClockText.hours(skin.view.now, Config.bar?.use12hFormat ?? false) + ":" + ClockText.minutes(skin.view.now)
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
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: skin.light ? skin.frost : Colors.shadow
                    shadowOpacity: skin.light ? 0.7 : 0.5
                    shadowBlur: 1
                    shadowVerticalOffset: 2
                    blurMax: 48
                }
            }
        }
    }

    passwordField: Component {
        LockPasswordBase {
            id: pw
            field: input
            implicitHeight: column.implicitHeight

            Column {
                id: column
                width: parent.width
                spacing: 12

                LockAvatar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    ink: skin.ink
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: skin.view.username
                    color: skin.ink
                    font.family: skin.font
                    font.pixelSize: Styling.fontSize(3)
                    font.weight: Font.DemiBold
                }
                Frost {
                    id: capsule
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 300)
                    height: 44
                    radius: height / 2 * skin.capsuleRadius
                    border.color: pw.errorShown ? skin.error : (input.activeFocus ? skin.alpha(skin.accent, 0.7) : skin.rim)
                    transform: Translate {
                        x: pw.shakeOffset
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
                        enabled: !pw.authenticating
                        color: skin.ink
                        selectionColor: skin.accent
                        selectedTextColor: skin.overAccent
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(0)
                        font.letterSpacing: pw.hasText ? 4 : 0.2
                        Keys.onReleased: event => pw.observeKey(event)
                    }
                    // Centred placeholder (the control hides its own when centred).
                    Text {
                        anchors.centerIn: parent
                        visible: !pw.hasText
                        text: I18n.t("lockscreen.password")
                        color: skin.alpha(skin.ink, 0.5)
                        font: input.font
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pw.capsLock
                        text: Icons.capsLock
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: skin.accent
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        radius: 16 * skin.capsuleRadius
                        color: skin.accent
                        opacity: pw.hasText || pw.authenticating ? 1 : 0
                        scale: pw.hasText || pw.authenticating ? 1 : 0.6

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                            }
                        }
                        Behavior on scale {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Motion.morph.easing
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: pw.authenticating ? Icons.circleNotch : Icons.arrowRight
                            font.family: Icons.font
                            font.pixelSize: 15
                            color: skin.overAccent
                            RotationAnimator on rotation {
                                running: pw.authenticating
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                            onTextChanged: if (!pw.authenticating)
                                rotation = 0
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: pw.hasText && !pw.authenticating
                            cursorShape: Qt.PointingHandCursor
                            onClicked: input.accepted()
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pw.hint
                    height: Math.max(implicitHeight, Styling.fontSize(-1) + 6)
                    color: pw.errorShown ? skin.error : skin.alpha(skin.ink, 0.8)
                    font.family: skin.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    opacity: pw.hint !== "" ? 1 : 0
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }
                }
            }
        }
    }

    mediaCard: Component {
        LockMediaBase {
            id: media
            implicitHeight: 76

            Frost {
                anchors.fill: parent
                radius: Math.min(22, Styling.radius(6)) * skin.capsuleRadius
            }

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Rectangle {
                    width: 56
                    height: 56
                    radius: 12 * skin.capsuleRadius
                    color: skin.alpha(skin.ink, 0.08)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: media.artUrl
                        sourceSize: Qt.size(112, 112)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: media.artUrl === ""
                        text: Icons.musicNotes
                        font.family: Icons.font
                        font.pixelSize: 22
                        color: skin.alpha(skin.ink, 0.6)
                    }
                }

                Column {
                    width: parent.width - 68 - controls.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: media.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: skin.ink
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: media.artist
                        visible: text !== ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: skin.alpha(skin.ink, 0.65)
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(-2)
                    }
                    Item {
                        width: parent.width
                        height: 18
                        NotchVisualizer {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            barCount: 22
                            spacing: 3
                            centered: true
                            idleOpacity: 0.3
                            visible: media.visualizerEnabled && CavaService.available
                            configEnabled: media.visualizerEnabled
                            startColor: skin.accent
                            endColor: skin.light ? Colors.overTertiaryFixedVariant : Colors.tertiaryFixedDim
                            playing: media.playing
                            shown: media.visualizerShown
                        }
                    }
                }

                Row {
                    id: controls
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    LockMediaButton {
                        icon: Icons.previous
                        glyphColor: skin.ink
                        onClicked: media.previous()
                    }
                    LockMediaButton {
                        icon: media.playing ? Icons.pause : Icons.play
                        filled: true
                        glyphColor: skin.ink
                        accent: skin.accent
                        overAccent: skin.overAccent
                        onClicked: media.toggle()
                    }
                    LockMediaButton {
                        icon: Icons.next
                        glyphColor: skin.ink
                        onClicked: media.next()
                    }
                }
            }
        }
    }

    // Connectivity and power in one frosted pill, top right.
    status: Component {
        Item {
            implicitHeight: 34

            LockStatusInfo {
                id: info
            }

            Frost {
                anchors.right: parent.right
                height: parent.height
                width: row.implicitWidth + 28
                radius: height / 2 * skin.capsuleRadius

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: info.networkIcon
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: skin.ink
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: info.batteryAvailable
                        text: info.batteryIcon
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: info.batteryLow ? skin.error : skin.ink
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: info.batteryAvailable
                        text: info.batteryPercent + "%"
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: skin.ink
                    }
                }
            }
        }
    }
}
