import QtQuick
import QtQuick.Controls
import ".."
import "../ClockText.js" as ClockText

// Poster / Kōyō (modules/lockscreen/styles/PosterStyle.qml): the wallpaper
// barely softened, hours over minutes in huge condensed numerals down the
// left (minutes in the accent), weekday and date in a grotesk beside them,
// a flat block with an accent tab for the password.
SddmStyle {
    id: skin

    readonly property color surface: light ? Qt.lighter(pal.secondaryFixed, 1.08) : pal.black
    readonly property real blockRadius: Math.min(greeter.roundness, 8)

    chipSurface: surface
    chipFill: alpha(surface, light ? 0.78 : 0.62)
    chipBorder: "transparent"
    chipBorderWidth: 0
    chipRoundness: Math.min(1, blockRadius / 18)
    chipFont: greeter.groteskFont
    chipCaps: true
    chipLetterSpacing: 1.6
    menuFill: alpha(surface, 0.94)

    arrangement: "split"
    clockSide: "left"
    wallpaperBlur: 0.18
    wallpaperZoom: 1.03
    clock: poster
    cluster: block
    passwordField: input

    backdrop: Rectangle {
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
                color: skin.alpha(skin.surface, 0.3)
            }
        }
    }

    Row {
        id: poster
        readonly property real digitSize: Math.round(Math.min(skin.height * 0.52, skin.width * 0.3))
        spacing: Math.round(digitSize * 0.06)

        Column {
            id: digits
            CssLine {
                text: ClockText.hours(skin.greeter.now, skin.greeter.use12h)
                family: skin.greeter.gothicFont
                size: poster.digitSize
                lineHeight: poster.digitSize * 0.8
                tracking: 0.01
                color: skin.ink
            }
            CssLine {
                text: ClockText.minutes(skin.greeter.now)
                family: skin.greeter.gothicFont
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
                visible: skin.greeter.use12h
                text: skin.greeter.now.getHours() < 12 ? "AM" : "PM"
                color: skin.accent
                font.family: skin.greeter.groteskBoldFont
                font.pixelSize: Math.round(poster.digitSize * 0.09)
            }
            Text {
                text: skin.greeter.now.toLocaleDateString(Qt.locale(), "dddd").toUpperCase()
                color: skin.ink
                font.family: skin.greeter.groteskBoldFont
                font.pixelSize: Math.round(poster.digitSize * 0.085)
                font.letterSpacing: 1
            }
            Text {
                text: skin.greeter.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy").toUpperCase()
                color: skin.inkSoft
                font.family: skin.greeter.groteskFont
                font.pixelSize: Math.round(poster.digitSize * 0.045)
                font.letterSpacing: 3
            }
        }
    }

    Item {
        id: block
        width: 420
        height: 56 + 10 + hintText.height

        Rectangle {
            id: field
            width: parent.width
            height: 56
            radius: skin.blockRadius
            color: skin.alpha(skin.surface, skin.light ? 0.78 : 0.62)
            clip: true
            transform: Translate {
                x: skin.shakeOffset
            }

            Rectangle {
                width: 4
                height: parent.height
                color: skin.errorShown ? skin.error : (input.activeFocus ? skin.accent : skin.alpha(skin.ink, 0.4))
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
                readOnly: skin.greeter.authenticating
                color: skin.ink
                selectionColor: skin.accent
                selectedTextColor: skin.overAccent
                font.family: skin.greeter.groteskFont
                font.pixelSize: skin.hasText ? skin.greeter.fontSize + 2 : skin.greeter.fontSize
                font.letterSpacing: skin.hasText ? 5 : 2.4
                font.capitalization: Font.AllUppercase
                placeholderText: "Password"
                placeholderTextColor: skin.alpha(skin.ink, 0.5)
                focus: true
                onAccepted: skin.submit()
                onTextChanged: skin.edited()
                Keys.onEscapePressed: skin.cancel()
            }
            Text {
                anchors.right: submit.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: skin.greeter.capsLock
                text: skin.greeter.iconCapsLock
                font.family: skin.greeter.iconFont
                font.pixelSize: 16
                color: skin.accent
            }
            Rectangle {
                id: submit
                anchors.right: parent.right
                width: parent.height
                height: parent.height
                color: skin.hasText || skin.greeter.authenticating ? skin.accent : skin.alpha(skin.ink, 0.08)
                Behavior on color {
                    ColorAnimation {
                        duration: skin.greeter.animDuration
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: skin.greeter.authenticating ? skin.greeter.iconSpinner : skin.greeter.iconArrowRight
                    font.family: skin.greeter.iconFont
                    font.pixelSize: 18
                    color: skin.hasText || skin.greeter.authenticating ? skin.overAccent : skin.ink
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
            id: hintText
            anchors.top: field.bottom
            anchors.topMargin: 10
            text: skin.hint
            height: Math.max(implicitHeight, skin.greeter.fontSize + 5)
            color: skin.errorShown ? skin.error : skin.ink
            font.family: skin.greeter.groteskFont
            font.pixelSize: skin.greeter.fontSize - 1
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
            opacity: skin.hint !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: skin.greeter.animDuration
                }
            }
        }
    }
}
