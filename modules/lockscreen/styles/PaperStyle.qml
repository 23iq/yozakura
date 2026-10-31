pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.modules.lockscreen
import qs.modules.desktop.clockstyles
import qs.modules.services
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.widgets.defaultview
import qs.config
import "../../desktop/clockstyles/ClockText.js" as ClockText

// Paper (Sumi-e): washi paper over a faint ink wash of the wallpaper,
// mincho numerals, a vertical kanji date with a vermilion seal, and a
// single brush line for the password. Light tone: sumi ink on washi;
// dark tone: pale ink on charcoal paper.
LockStyle {
    id: skin

    readonly property color paper: light ? Qt.lighter(Colors.secondaryFixed, 1.1) : Qt.tint(Colors.shadow, alpha(Colors.secondaryFixed, 0.07))
    // Vermilion of the seal, from the palette's harmonised red.
    readonly property color shu: Qt.hsla(Colors.red.hslHue < 0 ? 0.02 : Colors.red.hslHue, 0.68, light ? 0.46 : 0.62, 1)
    readonly property string mincho: minchoMedium.name
    readonly property bool use12h: Config.bar?.use12hFormat ?? false
    readonly property real u: view ? Math.min(view.width / 1920, view.height / 1080) : 1

    ink: light ? Colors.overSecondaryFixed : Colors.secondaryFixed
    inkSoft: light ? Colors.overSecondaryFixedVariant : Colors.secondaryFixedDim
    accent: shu
    overAccent: paper
    error: shu

    arrangement: "split"
    clockSide: "right"
    clusterWidth: Space.controlXL * 4 - Space.s
    wallpaperBlur: 0.45
    wallpaperSaturation: -0.85
    wallpaperZoom: 1.04

    FontLoader {
        id: minchoMedium
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-Medium.subset.ttf")
    }
    FontLoader {
        id: minchoRegular
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-Regular.subset.ttf")
    }
    FontLoader {
        id: minchoBold
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-ExtraBold.subset.ttf")
    }

    // Thin brush stroke: full ink in the middle, fading at both ends.
    component Brush: Rectangle {
        id: brush
        property color ink: skin.ink
        property real strength: 1
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: skin.alpha(brush.ink, 0)
            }
            GradientStop {
                position: 0.12
                color: skin.alpha(brush.ink, 0.85 * brush.strength)
            }
            GradientStop {
                position: 0.7
                color: skin.alpha(brush.ink, 0.6 * brush.strength)
            }
            GradientStop {
                position: 1
                color: skin.alpha(brush.ink, 0)
            }
        }
    }

    backdrop: Component {
        Item {
            id: sheet

            // Washi over the ink wash of the wallpaper.
            Rectangle {
                anchors.fill: parent
                color: skin.alpha(skin.paper, 0.86)
            }
            // Ink pooling softly at the edges.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: skin.alpha(skin.ink, 0.07)
                    }
                    GradientStop {
                        position: 0.35
                        color: skin.alpha(skin.ink, 0)
                    }
                    GradientStop {
                        position: 0.75
                        color: skin.alpha(skin.ink, 0)
                    }
                    GradientStop {
                        position: 1
                        color: skin.alpha(skin.ink, 0.05)
                    }
                }
            }
            // Ensō: one open brush circle behind the clock.
            Shape {
                id: enso
                readonly property real d: Math.min(sheet.width, sheet.height) * 0.62
                width: d
                height: d
                x: sheet.width * 0.66 - d / 2
                y: sheet.height * 0.47 - d / 2
                opacity: skin.light ? 0.07 : 0.1
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: skin.ink
                    strokeWidth: Math.max(6, enso.d * 0.035)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: enso.d / 2
                        centerY: enso.d / 2
                        radiusX: enso.d / 2 - 20
                        radiusY: enso.d / 2 - 20
                        startAngle: -70
                        sweepAngle: 320
                    }
                }
            }
        }
    }

    // Mincho time stacked "21 / 47", a hairline, then the vertical kanji
    // date, weekday and seal (read top to bottom, right of the time).
    clock: Component {
        Row {
            id: clockRow
            readonly property real digitSize: Math.round(Math.min(skin.view.height * 0.2, skin.view.width * 0.11))
            spacing: Math.round(digitSize * 0.28)
            visible: minchoMedium.status === FontLoader.Ready

            Column {
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.right: parent.right
                    visible: skin.use12h
                    text: ClockText.kanjiMeridiem(skin.view.now)
                    font.family: skin.mincho
                    font.pixelSize: Math.round(clockRow.digitSize * 0.2)
                    color: skin.shu
                    renderType: Text.QtRendering
                }
                CssLine {
                    anchors.right: parent.right
                    text: ClockText.hours(skin.view.now, skin.use12h)
                    family: skin.mincho
                    weight: minchoMedium.font.weight
                    size: clockRow.digitSize
                    lineHeight: clockRow.digitSize * 0.96
                    tracking: -0.02
                    color: skin.ink
                }
                CssLine {
                    anchors.right: parent.right
                    text: ClockText.minutes(skin.view.now)
                    family: skin.mincho
                    weight: minchoMedium.font.weight
                    size: clockRow.digitSize
                    lineHeight: clockRow.digitSize * 0.96
                    tracking: -0.02
                    color: skin.alpha(skin.ink, 0.72)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Math.round(1.5 * skin.u))
                height: clockRow.digitSize * 1.5
                color: skin.alpha(skin.ink, 0.35)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(clockRow.digitSize * 0.12)

                VerticalText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ClockText.kanjiDate(skin.view.now)
                    family: skin.mincho
                    weight: minchoMedium.font.weight
                    size: Math.round(clockRow.digitSize * 0.24)
                    tracking: 0.2
                    color: skin.ink
                }
                VerticalText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ClockText.kanjiWeekday(skin.view.now)
                    family: minchoRegular.name
                    weight: minchoRegular.font.weight
                    size: Math.round(clockRow.digitSize * 0.16)
                    tracking: 0.4
                    color: skin.inkSoft
                }
                // Seal: the weekday's kanji, carved in vermilion.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(clockRow.digitSize * 0.26)
                    height: width
                    radius: Math.round(width * 0.12)
                    color: skin.shu

                    Text {
                        anchors.centerIn: parent
                        text: ClockText.KANJI_WEEKDAYS[skin.view.now.getDay()]
                        font.family: minchoBold.name
                        font.pixelSize: Math.round(parent.width * 0.66)
                        color: skin.paper
                        renderType: Text.QtRendering
                    }
                }
            }
        }
    }

    passwordField: Component {
        LockPasswordBase {
            id: pw
            field: input
            shakeAmplitude: 0.6
            implicitHeight: 52 + 12 + hintText.height

            Item {
                id: line
                width: parent.width
                height: Space.controlM + Space.s
                transform: Translate {
                    x: pw.shakeOffset
                }

                TextField {
                    id: input
                    anchors.left: parent.left
                    anchors.right: submit.left
                    anchors.rightMargin: Space.m
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Space.s
                    background: null
                    padding: 0
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    enabled: !pw.authenticating
                    color: skin.ink
                    selectionColor: skin.alpha(skin.ink, 0.25)
                    selectedTextColor: skin.ink
                    font.family: skin.font
                    font.pixelSize: Type.size("title")
                    font.letterSpacing: pw.hasText ? 6 : 1.5
                    font.weight: Font.Light
                    placeholderText: I18n.t("lockscreen.password")
                    placeholderTextColor: skin.alpha(skin.ink, 0.42)
                    Keys.onReleased: event => pw.observeKey(event)
                }

                LockSpinner {
                    id: submit
                    anchors.right: parent.right
                    anchors.verticalCenter: input.verticalCenter
                    busy: pw.authenticating
                    color: pw.hasText ? skin.ink : skin.alpha(skin.ink, 0.35)

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Space.s
                        enabled: pw.hasText && !pw.authenticating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.accepted()
                    }
                }

                Brush {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: input.activeFocus || pw.errorShown ? 3 : 2
                    ink: pw.errorShown ? skin.shu : skin.ink
                    strength: input.activeFocus ? 1 : 0.55
                }
            }

            KitText {
                id: hintText
                anchors.top: line.bottom
                anchors.topMargin: Space.m
                text: pw.hint
                height: Math.max(implicitHeight, Type.size("secondary") + Space.xs)
                color: pw.errorShown ? skin.shu : skin.inkSoft
                font.family: skin.font
                role: "secondary"
                font.letterSpacing: 0.6
                opacity: pw.hint !== "" ? 1 : 0

                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
            }
        }
    }

    mediaCard: Component {
        LockMediaBase {
            id: media
            implicitHeight: Space.controlL

            Row {
                anchors.fill: parent
                spacing: Space.l

                // Artwork as a small print with an ink frame.
                Art {
                    width: Space.controlL
                    height: Space.controlL
                    source: media.artUrl
                    icon: Icons.musicNotes
                    radius: 0
                }

                Column {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.xs

                    Row {
                        width: parent.width
                        spacing: Space.s

                        KitText {
                            width: parent.width - controls.width - Space.s
                            text: media.title
                            elide: Text.ElideRight
                            color: skin.ink
                            font.family: skin.font
                            role: "body"
                            font.weight: Font.Medium
                        }
                        Row {
                            id: controls
                            spacing: Space.xs
                            LockMediaButton {
                                icon: Icons.previous
                                glyphColor: skin.ink
                                implicitWidth: Space.xl
                                onClicked: media.previous()
                            }
                            LockMediaButton {
                                icon: media.playing ? Icons.pause : Icons.play
                                glyphColor: skin.ink
                                implicitWidth: Space.xl
                                onClicked: media.toggle()
                            }
                            LockMediaButton {
                                icon: Icons.next
                                glyphColor: skin.ink
                                implicitWidth: Space.xl
                                onClicked: media.next()
                            }
                        }
                    }
                    KitText {
                        width: parent.width
                        text: media.artist
                        visible: text !== ""
                        elide: Text.ElideRight
                        color: skin.inkSoft
                        font.family: skin.font
                        role: "secondary"
                    }
                    Item {
                        width: parent.width
                        height: Space.l

                        NotchVisualizer {
                            anchors.fill: parent
                            barCount: 40
                            spacing: Space.xs
                            centered: false
                            idleOpacity: 0.3
                            visible: media.visualizerEnabled && CavaService.available
                            configEnabled: media.visualizerEnabled
                            startColor: skin.ink
                            endColor: skin.shu
                            playing: media.playing
                            shown: media.visualizerShown
                        }
                    }
                    Brush {
                        width: Math.max(Space.s, parent.width * media.progress)
                        height: 2
                        visible: media.length > 0
                    }
                }
            }
        }
    }

    status: Component {
        Item {
            implicitHeight: Space.xl

            LockStatusInfo {
                id: info
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s

                LockAvatar {
                    width: Space.xl
                    height: Space.xl
                    radius: Space.smallRadius
                    name: skin.view.username
                    anchors.verticalCenter: parent.verticalCenter
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: skin.view.username
                    color: skin.ink
                    font.family: skin.font
                    role: "body"
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
            }

            KitText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: [info.networkLabel, info.batteryAvailable ? info.batteryPercent + "%" : ""].filter(s => s !== "").join("   ·   ")
                color: info.batteryLow ? skin.shu : skin.inkSoft
                font.family: skin.font
                role: "secondary"
                font.letterSpacing: 1.5
            }
        }
    }
}
