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

// Neon (Neon Tokyo): OLED black, thin clock digits lit like a neon tube in a
// single accent (the palette's primary hue at full saturation), everything
// else in quiet grey. Dark only.
LockStyle {
    id: skin

    readonly property real hue: Colors.primary.hslHue < 0 ? 0.88 : Colors.primary.hslHue
    // The one neon colour, its white-hot core and the error tube.
    readonly property color neon: Qt.hsla(hue, 1, 0.62, 1)
    readonly property color core: Qt.hsla(hue, 1, 0.86, 1)
    readonly property color black: Colors.shadow
    readonly property real tubeRadius: Config.roundness > 0 ? Math.min(1, Config.roundness / 16) : 0

    ink: Qt.hsla(hue, 0.08, 0.86, 1)
    inkSoft: Qt.hsla(hue, 0.06, 0.55, 1)
    accent: neon
    overAccent: black
    error: Qt.hsla(Colors.error.hslHue < 0 ? 0 : Colors.error.hslHue, 1, 0.62, 1)

    arrangement: "stack"
    clusterWidth: 400
    clusterSpacing: 26
    wallpaperOpacity: 0
    wallpaperBlur: 0

    // Neon glow around the item it is set on.
    component Glow: MultiEffect {
        property color tint: skin.neon
        shadowEnabled: true
        shadowColor: tint
        shadowOpacity: 0.95
        shadowBlur: 1
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 48
    }

    // Quiet uppercase label.
    component Caps: Text {
        color: skin.inkSoft
        font.family: skin.font
        font.pixelSize: Styling.fontSize(-2)
        font.letterSpacing: 2.5
        font.weight: Font.Medium
    }

    backdrop: Component {
        Item {
            id: night

            Rectangle {
                anchors.fill: parent
                color: skin.black
            }
            // Faint haze of the sign on the floor.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: night.width / 2
                        centerY: night.height * (skin.view.atTop ? 0.62 : 0.4)
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
    }

    clock: Component {
        Column {
            id: clockColumn
            readonly property real digitSize: Math.round(Math.min(skin.view.height * 0.22, skin.view.width * 0.16))
            spacing: Math.round(digitSize * 0.02)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockText.hours(skin.view.now, Config.bar?.use12hFormat ?? false) + ":" + ClockText.minutes(skin.view.now)
                color: skin.core
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
                layer.enabled: true
                layer.effect: Glow {}
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: skin.view.now.toLocaleDateString(Qt.locale(), "dddd  d MMMM").toUpperCase()
                color: skin.inkSoft
                font.family: skin.font
                font.pixelSize: Math.max(14, Math.round(clockColumn.digitSize * 0.085))
                font.weight: Font.Medium
                font.letterSpacing: Math.round(clockColumn.digitSize * 0.03)
            }
        }
    }

    passwordField: Component {
        LockPasswordBase {
            id: pw
            field: input
            implicitHeight: 48 + 14 + hintText.height
            readonly property color tube: errorShown ? skin.error : skin.neon

            Item {
                id: line
                width: parent.width
                height: 48
                transform: Translate {
                    x: pw.shakeOffset
                }

                Text {
                    id: lead
                    anchors.left: parent.left
                    anchors.verticalCenter: input.verticalCenter
                    text: pw.capsLock ? Icons.capsLock : Icons.lock
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: pw.capsLock ? skin.neon : skin.inkSoft
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
                    enabled: !pw.authenticating
                    color: skin.ink
                    selectionColor: skin.neon
                    selectedTextColor: skin.black
                    font.family: skin.font
                    font.pixelSize: pw.hasText ? Styling.fontSize(5) : Styling.fontSize(1)
                    font.letterSpacing: pw.hasText ? 5 : 3
                    font.capitalization: pw.hasText ? Font.MixedCase : Font.AllUppercase
                    placeholderText: I18n.t("lockscreen.password")
                    placeholderTextColor: skin.inkSoft
                    Keys.onReleased: event => pw.observeKey(event)
                }
                Text {
                    id: submit
                    anchors.right: parent.right
                    anchors.verticalCenter: input.verticalCenter
                    text: pw.authenticating ? Icons.circleNotch : Icons.keyReturn
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: pw.hasText ? skin.neon : skin.inkSoft
                    RotationAnimator on rotation {
                        running: pw.authenticating
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                    onTextChanged: if (!pw.authenticating)
                        rotation = 0
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: pw.hasText && !pw.authenticating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.accepted()
                    }
                }
                // The tube: dim until focused, lit (with glow) while typing.
                Rectangle {
                    id: tubeLine
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    radius: 1
                    color: pw.tube
                    opacity: input.activeFocus || pw.errorShown ? 1 : 0.35
                    layer.enabled: input.activeFocus || pw.errorShown
                    layer.effect: Glow {
                        tint: pw.tube
                    }
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Motion.enter.duration
                        }
                    }
                }
            }
            Text {
                id: hintText
                anchors.top: line.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                text: pw.hint.toUpperCase()
                height: Math.max(implicitHeight, Styling.fontSize(-2) + 6)
                color: pw.errorShown ? skin.error : skin.neon
                font.family: skin.font
                font.pixelSize: Styling.fontSize(-2)
                font.letterSpacing: 2.5
                opacity: pw.hint !== "" ? 1 : 0
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                    }
                }
            }
        }
    }

    mediaCard: Component {
        LockMediaBase {
            id: media
            implicitHeight: 74

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Math.min(18, Styling.radius(4)) * skin.tubeRadius
                border.color: skin.alpha(skin.neon, 0.32)
                border.width: 1
            }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Rectangle {
                    width: 50
                    height: 50
                    radius: 8 * skin.tubeRadius
                    color: skin.alpha(skin.ink, 0.06)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: media.artUrl
                        sourceSize: Qt.size(100, 100)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: media.artUrl === ""
                        text: Icons.musicNotes
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: skin.neon
                    }
                }
                Column {
                    width: parent.width - 64 - controls.width - 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: media.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: skin.ink
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: media.artist.toUpperCase()
                        visible: text !== ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: skin.inkSoft
                        font.family: skin.font
                        font.pixelSize: Styling.fontSize(-3)
                        font.letterSpacing: 1.5
                    }
                    NotchVisualizer {
                        width: parent.width
                        height: 14
                        barCount: 26
                        spacing: 3
                        centered: true
                        idleOpacity: 0.25
                        visible: media.visualizerEnabled && CavaService.available
                        configEnabled: media.visualizerEnabled
                        startColor: skin.neon
                        endColor: skin.neon
                        playing: media.playing
                        shown: media.visualizerShown
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
                        glyphColor: skin.neon
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

    status: Component {
        Item {
            implicitHeight: 24

            LockStatusInfo {
                id: info
            }
            Caps {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: skin.view.username.toUpperCase()
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                Caps {
                    text: info.networkLabel.toUpperCase()
                    visible: text !== ""
                }
                Caps {
                    visible: info.batteryAvailable
                    text: info.batteryPercent + "%"
                    color: info.batteryLow ? skin.error : skin.inkSoft
                }
            }
        }
    }
}
