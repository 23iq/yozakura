import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import ".."
import "../ClockText.js" as ClockText

// Paper / Sumi-e (modules/lockscreen/styles/PaperStyle.qml): washi over a
// faint ink wash of the wallpaper, mincho numerals with a vertical kanji
// date and a vermilion seal, a single brush line for the password.
SddmStyle {
    id: skin

    readonly property color paper: light ? Qt.lighter(pal.secondaryFixed, 1.1) : Qt.tint(pal.black, alpha(pal.secondaryFixed, 0.07))
    // Vermilion of the seal, from the palette's harmonised red.
    readonly property color shu: Qt.hsla(pal.red.hslHue < 0 ? 0.02 : pal.red.hslHue, 0.68, light ? 0.46 : 0.62, 1)

    ink: light ? pal.overSecondaryFixed : pal.secondaryFixed
    inkSoft: light ? pal.overSecondaryFixedVariant : pal.secondaryFixedDim
    accent: shu
    overAccent: paper
    error: shu

    chipSurface: paper
    chipFill: "transparent"
    chipBorder: alpha(ink, 0.25)
    chipRoundness: 0.15
    chipLetterSpacing: 1.5
    menuFill: alpha(paper, 0.96)

    arrangement: "split"
    clockSide: "right"
    wallpaperBlur: 0.45
    wallpaperSaturation: -0.85
    wallpaperZoom: 1.04
    clock: clockRow
    cluster: line
    passwordField: input
    shakeAmplitude: 0.6

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

    backdrop: Item {
        id: sheet
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: skin.alpha(skin.paper, 0.86)
        }
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
            readonly property real d: Math.min(sheet.width, sheet.height) * 0.62
            visible: !skin.greeter.softwareRendering
            width: d
            height: d
            x: sheet.width * 0.66 - d / 2
            y: sheet.height * 0.47 - d / 2
            opacity: skin.light ? 0.07 : 0.1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: skin.ink
                strokeWidth: Math.max(6, parent.d * 0.035)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: parent.d / 2
                    centerY: parent.d / 2
                    radiusX: parent.d / 2 - 20
                    radiusY: parent.d / 2 - 20
                    startAngle: -70
                    sweepAngle: 320
                }
            }
        }
    }

    // Mincho "21 / 47", a hairline, the vertical kanji date and the seal.
    Row {
        id: clockRow
        readonly property real digitSize: Math.round(Math.min(skin.height * 0.2, skin.width * 0.11))
        spacing: Math.round(digitSize * 0.28)

        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.right: parent.right
                visible: skin.greeter.use12h
                text: ClockText.kanjiMeridiem(skin.greeter.now)
                font.family: skin.greeter.minchoFont
                font.pixelSize: Math.round(clockRow.digitSize * 0.2)
                color: skin.shu
                renderType: Text.QtRendering
            }
            CssLine {
                anchors.right: parent.right
                text: ClockText.hours(skin.greeter.now, skin.greeter.use12h)
                family: skin.greeter.minchoFont
                size: clockRow.digitSize
                lineHeight: clockRow.digitSize * 0.96
                tracking: -0.02
                color: skin.ink
            }
            CssLine {
                anchors.right: parent.right
                text: ClockText.minutes(skin.greeter.now)
                family: skin.greeter.minchoFont
                size: clockRow.digitSize
                lineHeight: clockRow.digitSize * 0.96
                tracking: -0.02
                color: skin.alpha(skin.ink, 0.72)
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: clockRow.digitSize * 1.5
            color: skin.alpha(skin.ink, 0.35)
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(clockRow.digitSize * 0.12)

            VerticalText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockText.kanjiDate(skin.greeter.now)
                family: skin.greeter.minchoFont
                size: Math.round(clockRow.digitSize * 0.24)
                tracking: 0.2
                color: skin.ink
            }
            VerticalText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockText.kanjiWeekday(skin.greeter.now)
                family: skin.greeter.minchoRegularFont
                size: Math.round(clockRow.digitSize * 0.16)
                tracking: 0.4
                color: skin.inkSoft
            }
            // Seal: the weekday's kanji in vermilion.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(clockRow.digitSize * 0.26)
                height: width
                radius: Math.round(width * 0.12)
                color: skin.shu
                Text {
                    anchors.centerIn: parent
                    text: ClockText.KANJI_WEEKDAYS[skin.greeter.now.getDay()]
                    font.family: skin.greeter.minchoBoldFont
                    font.pixelSize: Math.round(parent.width * 0.66)
                    color: skin.paper
                    renderType: Text.QtRendering
                }
            }
        }
    }

    // One brush line for the password, the hint below.
    Item {
        id: line
        width: 380
        height: 52 + 12 + hintText.height

        Item {
            id: field
            width: parent.width
            height: 52
            transform: Translate {
                x: skin.shakeOffset
            }

            TextField {
                id: input
                anchors.left: parent.left
                anchors.right: submit.left
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                background: null
                padding: 0
                echoMode: TextInput.Password
                passwordCharacter: "•"
                readOnly: skin.greeter.authenticating
                color: skin.ink
                selectionColor: skin.alpha(skin.ink, 0.25)
                selectedTextColor: skin.ink
                font.family: skin.font
                font.pixelSize: skin.hasText ? skin.greeter.fontSize + 5 : skin.greeter.fontSize + 2
                font.letterSpacing: skin.hasText ? 6 : 1.5
                font.weight: Font.Light
                placeholderText: "Password"
                placeholderTextColor: skin.alpha(skin.ink, 0.42)
                focus: true
                onAccepted: skin.submit()
                onTextChanged: skin.edited()
                Keys.onEscapePressed: skin.cancel()
            }
            Text {
                id: submit
                anchors.right: parent.right
                anchors.verticalCenter: input.verticalCenter
                text: skin.greeter.authenticating ? skin.greeter.iconSpinner : skin.greeter.iconArrowRight
                font.family: skin.greeter.iconFont
                font.pixelSize: 18
                color: skin.hasText ? skin.ink : skin.alpha(skin.ink, 0.35)
                RotationAnimator on rotation {
                    running: skin.greeter.authenticating
                    from: 0
                    to: 360
                    duration: 1200
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
            Brush {
                anchors.bottom: parent.bottom
                width: parent.width
                height: input.activeFocus || skin.errorShown ? 3 : 2
                ink: skin.errorShown ? skin.shu : skin.ink
                strength: input.activeFocus ? 1 : 0.55
            }
        }
        Text {
            id: hintText
            anchors.top: field.bottom
            anchors.topMargin: 12
            text: skin.hint
            height: Math.max(implicitHeight, skin.greeter.fontSize + 5)
            color: skin.errorShown ? skin.shu : skin.inkSoft
            font.family: skin.font
            font.pixelSize: skin.greeter.fontSize - 1
            font.letterSpacing: 0.6
            opacity: skin.hint !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: skin.greeter.animDuration
                }
            }
        }
    }
}
