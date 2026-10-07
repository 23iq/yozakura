pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.lockscreen
import qs.modules.desktop.clockstyles
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.config
import "../../desktop/clockstyles/ClockText.js" as ClockText

// Poster (Kōyō): the wallpaper barely softened, hours over minutes in huge
// condensed poster numerals down the left side (minutes in the accent), the
// weekday and date set beside them in a grotesk, flat blocks for the media
// card and password. Dark tone: shade from the left; light tone: paper veil.
LockStyle {
    id: skin

    readonly property color surface: light ? Qt.lighter(Colors.secondaryFixed, 1.08) : Colors.shadow
    readonly property string gothicFont: gothic.name
    readonly property string grotesk: groteskMedium.status === FontLoader.Ready ? groteskMedium.name : font
    readonly property string groteskHeavy: groteskBold.status === FontLoader.Ready ? groteskBold.name : font
    readonly property real blockRadius: Math.min(Config.roundness, 8)
    readonly property bool use12h: Config.bar?.use12hFormat ?? false

    arrangement: "split"
    clockSide: "left"
    clusterWidth: 420
    clusterSpacing: 14
    wallpaperBlur: 0.18
    wallpaperZoom: 1.03

    FontLoader {
        id: gothic
        source: Qt.resolvedUrl("../../../assets/fonts/clock/LeagueGothic-Regular.ttf")
    }
    FontLoader {
        id: groteskMedium
        source: Qt.resolvedUrl("../../../assets/fonts/clock/SpaceGrotesk-Medium.otf")
    }
    FontLoader {
        id: groteskBold
        source: Qt.resolvedUrl("../../../assets/fonts/clock/SpaceGrotesk-Bold.otf")
    }

    // Uppercase grotesk label.
    component Label: Text {
        color: skin.ink
        font.family: skin.grotesk
        font.pixelSize: Styling.fontSize(-1)
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase
        textFormat: Text.PlainText
    }

    // Flat block with an accent tab on its leading edge.
    component Block: Rectangle {
        property color tab: skin.accent
        color: skin.alpha(skin.surface, skin.light ? 0.78 : 0.62)
        radius: skin.blockRadius
        clip: true
        Rectangle {
            width: 4
            height: parent.height
            color: parent.tab
        }
    }

    backdrop: Component {
        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: skin.alpha(skin.surface, skin.light ? 0.72 : 0.78)
                    }
                    GradientStop {
                        position: 0.55
                        color: skin.alpha(skin.surface, skin.light ? 0.4 : 0.42)
                    }
                    GradientStop {
                        position: 1
                        color: skin.alpha(skin.surface, skin.light ? 0.3 : 0.3)
                    }
                }
            }
        }
    }

    clock: Component {
        Row {
            id: poster
            readonly property real digitSize: Math.round(Math.min(skin.view.height * 0.52, skin.view.width * 0.3))
            spacing: Math.round(digitSize * 0.06)
            visible: gothic.status === FontLoader.Ready

            Column {
                id: digits
                CssLine {
                    text: ClockText.hours(skin.view.now, skin.use12h)
                    family: skin.gothicFont
                    size: poster.digitSize
                    lineHeight: poster.digitSize * 0.8
                    tracking: 0.01
                    color: skin.ink
                }
                CssLine {
                    text: ClockText.minutes(skin.view.now)
                    family: skin.gothicFont
                    size: poster.digitSize
                    lineHeight: poster.digitSize * 0.8
                    tracking: 0.01
                    color: skin.accent
                }
            }

            Column {
                anchors.bottom: digits.bottom
                anchors.bottomMargin: Math.round(poster.digitSize * 0.06)
                spacing: Math.round(poster.digitSize * 0.025)

                Rectangle {
                    width: Math.round(poster.digitSize * 0.18)
                    height: 4
                    color: skin.accent
                }
                Text {
                    visible: skin.use12h
                    text: skin.view.now.getHours() < 12 ? "AM" : "PM"
                    color: skin.accent
                    font.family: skin.groteskHeavy
                    font.pixelSize: Math.round(poster.digitSize * 0.09)
                }
                Text {
                    text: skin.view.now.toLocaleDateString(Qt.locale(), "dddd").toUpperCase()
                    color: skin.ink
                    font.family: skin.groteskHeavy
                    font.pixelSize: Math.round(poster.digitSize * 0.085)
                    font.letterSpacing: 1
                }
                Text {
                    text: skin.view.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy").toUpperCase()
                    color: skin.inkSoft
                    font.family: skin.grotesk
                    font.pixelSize: Math.round(poster.digitSize * 0.045)
                    font.letterSpacing: 3
                }
            }
        }
    }

    passwordField: Component {
        LockPasswordBase {
            id: pw
            field: input
            implicitHeight: 56 + 10 + hintText.height

            Block {
                id: block
                width: parent.width
                height: 56
                tab: pw.errorShown ? skin.error : (input.activeFocus ? skin.accent : skin.alpha(skin.ink, 0.4))
                transform: Translate {
                    x: pw.shakeOffset
                }

                TextField {
                    id: input
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.right: submit.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    background: null
                    padding: 0
                    echoMode: TextInput.Password
                    passwordCharacter: "■"
                    enabled: !pw.authenticating
                    color: skin.ink
                    selectionColor: skin.accent
                    selectedTextColor: skin.overAccent
                    font.family: skin.grotesk
                    font.pixelSize: pw.hasText ? Styling.fontSize(2) : Styling.fontSize(0)
                    font.letterSpacing: pw.hasText ? 5 : 2.4
                    font.capitalization: Font.AllUppercase
                    placeholderText: I18n.t("lockscreen.password")
                    placeholderTextColor: skin.alpha(skin.ink, 0.5)
                    Keys.onReleased: event => pw.observeKey(event)
                }
                Text {
                    anchors.right: submit.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.capsLock
                    text: Icons.capsLock
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: skin.accent
                }
                Rectangle {
                    id: submit
                    anchors.right: parent.right
                    width: parent.height
                    height: parent.height
                    color: pw.hasText || pw.authenticating ? skin.accent : skin.alpha(skin.ink, 0.08)
                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Motion.enter.duration
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: pw.authenticating ? Icons.circleNotch : Icons.arrowRight
                        font.family: Icons.font
                        font.pixelSize: 18
                        color: pw.hasText || pw.authenticating ? skin.overAccent : skin.ink
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
            Label {
                id: hintText
                anchors.top: block.bottom
                anchors.topMargin: 10
                text: pw.hint
                height: Math.max(implicitHeight, Styling.fontSize(-1) + 6)
                color: pw.errorShown ? skin.error : skin.ink
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
            implicitHeight: 88

            Block {
                anchors.fill: parent

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    spacing: 14

                    Rectangle {
                        width: parent.height
                        height: parent.height
                        color: skin.alpha(skin.ink, 0.08)
                        Image {
                            anchors.fill: parent
                            source: media.artUrl
                            sourceSize: Qt.size(176, 176)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: media.artUrl === ""
                            text: Icons.musicNotes
                            font.family: Icons.font
                            font.pixelSize: 26
                            color: skin.accent
                        }
                    }
                    Column {
                        width: parent.width - parent.height - 28
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: parent.width
                            text: media.title.toUpperCase()
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: skin.ink
                            font.family: skin.groteskHeavy
                            font.pixelSize: Styling.fontSize(1)
                        }
                        Label {
                            width: parent.width
                            text: media.artist
                            visible: text !== ""
                            elide: Text.ElideRight
                            color: skin.inkSoft
                            font.pixelSize: Styling.fontSize(-2)
                        }
                        Row {
                            width: parent.width
                            spacing: 4
                            LockMediaButton {
                                icon: Icons.previous
                                glyphColor: skin.ink
                                roundness: 0.15
                                onClicked: media.previous()
                            }
                            LockMediaButton {
                                icon: media.playing ? Icons.pause : Icons.play
                                filled: true
                                roundness: 0.15
                                glyphColor: skin.ink
                                accent: skin.accent
                                overAccent: skin.overAccent
                                onClicked: media.toggle()
                            }
                            LockMediaButton {
                                icon: Icons.next
                                glyphColor: skin.ink
                                roundness: 0.15
                                onClicked: media.next()
                            }
                            NotchVisualizer {
                                width: parent.width - 106
                                height: 24
                                anchors.verticalCenter: parent.verticalCenter
                                barCount: 20
                                spacing: 3
                                centered: false
                                idleOpacity: 0.3
                                visible: media.visualizerEnabled && CavaService.available
                                configEnabled: media.visualizerEnabled
                                startColor: skin.accent
                                endColor: skin.ink
                                playing: media.playing
                                shown: media.visualizerShown
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width * media.progress
                    height: 3
                    color: skin.accent
                    visible: media.length > 0
                }
            }
        }
    }

    status: Component {
        Item {
            implicitHeight: 26

            LockStatusInfo {
                id: info
            }
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    width: 10
                    height: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: skin.accent
                }
                Label {
                    text: skin.view.username
                    font.family: skin.groteskHeavy
                }
            }
            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: [info.networkLabel, info.batteryAvailable ? info.batteryPercent + "%" : ""].filter(s => s !== "").join("  /  ")
                color: info.batteryLow ? skin.error : skin.ink
            }
        }
    }
}
