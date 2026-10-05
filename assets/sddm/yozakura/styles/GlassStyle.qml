import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// Glass (modules/lockscreen/styles/GlassStyle.qml): blurred wallpaper under a
// vignette, heavy clock with rolling digits and an accent colon, glass pill.
// Dark tone: black glass; light tone: frosted white glass.
SddmStyle {
    id: skin

    readonly property color surface: light ? Qt.lighter(pal.secondaryFixed, 1.08) : pal.black
    readonly property real dim: light ? 0.28 : 0.34

    arrangement: "stack"
    wallpaperBlur: 0.7
    clock: clockItem
    cluster: pill
    passwordField: input

    backdrop: Item {
        id: shade
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: skin.alpha(skin.surface, skin.dim)
        }
        // Vignette: clear centre, deep corners.
        Shape {
            anchors.fill: parent
            visible: !skin.greeter.softwareRendering
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: shade.width / 2
                    centerY: shade.height * 0.45
                    centerRadius: Math.hypot(shade.width, shade.height) * 0.6
                    focalX: centerX
                    focalY: centerY
                    GradientStop {
                        position: 0.0
                        color: skin.alpha(skin.surface, 0.0)
                    }
                    GradientStop {
                        position: 0.45
                        color: skin.alpha(skin.surface, 0.08)
                    }
                    GradientStop {
                        position: 1.0
                        color: skin.alpha(skin.surface, skin.light ? 0.5 : 0.72)
                    }
                }
                PathRectangle {
                    width: shade.width
                    height: shade.height
                }
            }
        }
        // Deeper floor behind the password pill.
        Rectangle {
            width: parent.width
            height: parent.height * 0.5
            y: skin.greeter.atTop ? 0 : parent.height - height
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: skin.alpha(skin.surface, skin.greeter.atTop ? 0.55 : 0.0)
                }
                GradientStop {
                    position: 1.0
                    color: skin.alpha(skin.surface, skin.greeter.atTop ? 0.0 : 0.55)
                }
            }
        }
        // Light scrim under the status chips.
        Rectangle {
            width: parent.width
            height: Math.min(200, parent.height * 0.2)
            y: skin.greeter.atTop ? parent.height - height : 0
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: skin.alpha(skin.surface, skin.greeter.atTop ? 0.0 : 0.35)
                }
                GradientStop {
                    position: 1.0
                    color: skin.alpha(skin.surface, skin.greeter.atTop ? 0.35 : 0.0)
                }
            }
        }
    }

    // ---------------------------------------------------------------- clock --

    Item {
        id: clockItem
        readonly property real pixelSize: Math.round(Math.min(skin.height * 0.22, skin.width * 0.16))
        readonly property string hoursText: skin.greeter.use12h ? String(skin.greeter.now.getHours() % 12 || 12) : (skin.greeter.now.getHours() < 10 ? "0" : "") + skin.greeter.now.getHours()
        readonly property string minutesText: (skin.greeter.now.getMinutes() < 10 ? "0" : "") + skin.greeter.now.getMinutes()
        readonly property real digitTrim: Math.round(fontMetrics.descent * 0.9)
        width: Math.max(digits.width, dateLabel.implicitWidth)
        height: digits.height - digitTrim + dateLabel.implicitHeight

        // Variable fonts only reach the heaviest instance through wght.
        Text {
            id: fontSource
            visible: false
            font.family: skin.font
            font.pixelSize: clockItem.pixelSize
            font.weight: Font.Black
            font.variableAxes: ({
                    "wght": 900
                })
            font.features: ({
                    "tnum": 1
                })
        }
        FontMetrics {
            id: fontMetrics
            font: fontSource.font
        }
        TextMetrics {
            id: zeroMetrics
            font: fontSource.font
            text: "0"
        }

        Item {
            anchors.fill: parent
            layer.enabled: !skin.greeter.softwareRendering
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.surface
                shadowOpacity: skin.light ? 0.5 : 0.7
                shadowBlur: 1.0
                shadowVerticalOffset: 2
                blurMax: 48
            }

            Row {
                id: digits
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -Math.round(clockItem.pixelSize * 0.03)

                Digit {
                    font: fontSource.font
                    color: skin.ink
                    cellWidth: Math.ceil(zeroMetrics.advanceWidth)
                    value: clockItem.hoursText.length > 1 ? clockItem.hoursText.charAt(0) : ""
                    visible: clockItem.hoursText.length > 1
                }
                Digit {
                    font: fontSource.font
                    color: skin.ink
                    cellWidth: Math.ceil(zeroMetrics.advanceWidth)
                    value: clockItem.hoursText.charAt(clockItem.hoursText.length - 1)
                }
                // The only accent on the clock: the colon.
                Text {
                    text: ":"
                    font.family: skin.font
                    font.pixelSize: Math.round(clockItem.pixelSize * 0.9)
                    font.weight: Font.Bold
                    font.variableAxes: ({
                            "wght": 700
                        })
                    color: skin.accent
                    renderType: Text.QtRendering
                    leftPadding: Math.round(clockItem.pixelSize * 0.05)
                    rightPadding: Math.round(clockItem.pixelSize * 0.05)
                    y: Math.round((fontMetrics.height - height) / 2 - clockItem.pixelSize * 0.04)
                }
                Digit {
                    font: fontSource.font
                    color: skin.ink
                    cellWidth: Math.ceil(zeroMetrics.advanceWidth)
                    value: clockItem.minutesText.charAt(0)
                }
                Digit {
                    font: fontSource.font
                    color: skin.ink
                    cellWidth: Math.ceil(zeroMetrics.advanceWidth)
                    value: clockItem.minutesText.charAt(1)
                }
                Text {
                    visible: skin.greeter.use12h
                    text: skin.greeter.now.getHours() < 12 ? "AM" : "PM"
                    font.family: skin.font
                    font.pixelSize: Math.round(clockItem.pixelSize * 0.16)
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: skin.ink
                    opacity: 0.8
                    leftPadding: Math.round(clockItem.pixelSize * 0.06)
                    y: Math.round(clockItem.pixelSize * 0.3)
                }
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: digits.height - clockItem.digitTrim
                text: skin.greeter.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                font.family: skin.font
                font.pixelSize: Math.max(16, Math.round(clockItem.pixelSize * 0.13))
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
                color: skin.ink
                opacity: 0.88
            }
        }
    }

    // ------------------------------------------------------- password pill --

    Item {
        id: pill
        readonly property real pillHeight: 54
        width: 420
        height: pillHeight + 10 + hintLabel.height

        Rectangle {
            id: glass
            width: parent.width
            height: pill.pillHeight
            radius: (height / 2) * skin.greeter.roundnessFactor
            color: skin.alpha(skin.surface, 0.62)
            border.width: (skin.greeter.showError || input.activeFocus) ? 1.5 : 1
            border.color: {
                if (skin.greeter.showError)
                    return skin.error;
                if (input.activeFocus)
                    return skin.alpha(skin.accent, 0.85);
                return skin.alpha(skin.ink, 0.12);
            }
            antialiasing: true
            Behavior on border.color {
                ColorAnimation {
                    duration: skin.greeter.animDuration
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                x: skin.shakeOffset
            }

            Text {
                id: leadIcon
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: skin.greeter.iconLock
                font.family: skin.greeter.iconFont
                font.pixelSize: 17
                color: skin.greeter.showError ? skin.error : skin.ink
                opacity: skin.greeter.showError ? 1 : 0.7
            }

            TextField {
                id: input
                anchors.left: leadIcon.right
                anchors.leftMargin: 12
                anchors.right: capsIcon.visible ? capsIcon.left : submit.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                background: null
                padding: 0
                echoMode: TextInput.Password
                passwordCharacter: "•"
                verticalAlignment: TextInput.AlignVCenter
                readOnly: skin.greeter.authenticating
                color: skin.ink
                selectionColor: skin.accent
                selectedTextColor: skin.overAccent
                font.family: skin.font
                font.pixelSize: skin.hasText ? skin.greeter.fontSize + 6 : skin.greeter.fontSize + 1
                font.letterSpacing: skin.hasText ? 3 : 0.2
                placeholderText: "Password"
                placeholderTextColor: skin.alpha(skin.ink, 0.5)
                focus: true
                onAccepted: skin.submit()
                onTextChanged: skin.edited()
                Keys.onEscapePressed: skin.cancel()
            }

            Text {
                id: capsIcon
                anchors.right: submit.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: opacity > 0
                opacity: skin.greeter.capsLock ? 1 : 0
                text: skin.greeter.iconCapsLock
                font.family: skin.greeter.iconFont
                font.pixelSize: 17
                color: skin.accent
                Behavior on opacity {
                    NumberAnimation {
                        duration: skin.greeter.animDuration
                    }
                }
            }

            Item {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: pill.pillHeight - 18
                height: width
                readonly property bool armed: skin.hasText || skin.greeter.authenticating

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: submit.armed ? skin.accent : skin.alpha(skin.ink, 0.10)
                    scale: submitMouse.pressed ? 0.9 : 1
                    Behavior on color {
                        ColorAnimation {
                            duration: skin.greeter.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !skin.greeter.authenticating
                    text: skin.greeter.iconArrowRight
                    font.family: skin.greeter.iconFont
                    font.pixelSize: 16
                    color: submit.armed ? skin.overAccent : skin.ink
                }
                Text {
                    anchors.centerIn: parent
                    visible: skin.greeter.authenticating
                    text: skin.greeter.iconSpinner
                    font.family: skin.greeter.iconFont
                    font.pixelSize: 16
                    color: skin.overAccent
                    RotationAnimator on rotation {
                        running: skin.greeter.authenticating
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }
                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    enabled: skin.hasText && !skin.greeter.authenticating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: skin.submit()
                }
            }
        }

        Text {
            id: hintLabel
            anchors.top: glass.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            text: skin.hint
            color: skin.errorShown ? skin.error : skin.ink
            font.family: skin.font
            font.pixelSize: skin.greeter.fontSize - 1
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            opacity: skin.hint !== "" ? 0.95 : 0
            height: Math.max(implicitHeight, skin.greeter.fontSize + 5)
            Behavior on opacity {
                NumberAnimation {
                    duration: skin.greeter.animDuration
                }
            }
            layer.enabled: !skin.greeter.softwareRendering
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.surface
                shadowOpacity: 0.6
                shadowBlur: 0.6
                shadowVerticalOffset: 1
                blurMax: 24
            }
        }
    }
}
