pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.theme
import qs.config

// Glass style password field: a glass pill with a lock glyph, the masked
// text, a caps-lock mark and a round submit button; hints below.
LockPasswordBase {
    id: root

    property color textColor: Colors.secondaryFixed
    property color accent: Colors.primaryFixedDim
    property color overAccent: Colors.overPrimaryFixed
    property color errorColor: Colors.error
    property color fill: Colors.shadow
    property string fontFamily: Config.theme.font

    readonly property real pillHeight: 54
    readonly property real pillRadius: Config.roundness > 0 ? (pillHeight / 2) * Math.min(1, Config.roundness / 16) : 0
    readonly property color hintColor: errorShown ? errorColor : textColor

    field: passwordInput
    implicitWidth: 420
    implicitHeight: pillHeight + 10 + hintLabel.implicitHeight

    LockGlass {
        id: pill
        width: parent.width
        height: root.pillHeight
        radius: root.pillRadius
        fill: root.fill
        ink: root.textColor
        strength: 0.62
        ringWidth: (root.showError || passwordInput.activeFocus) ? 1.5 : 1
        ringColor: {
            if (root.showError)
                return root.errorColor;
            if (passwordInput.activeFocus)
                return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85);
            return Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12);
        }

        transform: Translate {
            x: root.shakeOffset
        }

        Behavior on ringColor {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        // Leading lock glyph
        Text {
            id: leadIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.lock
            font.family: Icons.font
            font.pixelSize: 17
            color: root.showError ? root.errorColor : root.textColor
            opacity: root.showError ? 1 : 0.7

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }

        TextField {
            id: passwordInput
            anchors.left: leadIcon.right
            anchors.leftMargin: 12
            anchors.right: capsIcon.visible ? capsIcon.left : submitButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            background: null
            padding: 0
            echoMode: TextInput.Password
            passwordCharacter: "•"
            verticalAlignment: TextInput.AlignVCenter
            enabled: !root.authenticating
            color: root.textColor
            selectionColor: root.accent
            selectedTextColor: root.overAccent
            font.family: root.fontFamily
            font.pixelSize: root.hasText ? Styling.fontSize(6) : Styling.fontSize(1)
            font.letterSpacing: root.hasText ? 3 : 0.2
            placeholderText: I18n.t("lockscreen.password")
            placeholderTextColor: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
            Keys.onReleased: event => root.observeKey(event)
        }

        // Caps lock indicator
        Text {
            id: capsIcon
            anchors.right: submitButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: opacity > 0
            opacity: root.capsLock ? 1 : 0
            text: Icons.capsLock
            font.family: Icons.font
            font.pixelSize: 17
            color: root.accent

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                }
            }
        }

        // Submit / progress button
        Item {
            id: submitButton
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: root.pillHeight - 18
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.hasText || root.authenticating ? root.accent : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                scale: submitMouse.pressed ? 0.9 : 1

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutBack
                    }
                }
            }

            Text {
                id: submitGlyph
                anchors.centerIn: parent
                text: root.authenticating ? Icons.circleNotch : Icons.arrowRight
                font.family: Icons.font
                font.pixelSize: 16
                color: root.hasText || root.authenticating ? root.overAccent : root.textColor

                RotationAnimator on rotation {
                    running: root.authenticating
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                }

                onTextChanged: if (!root.authenticating)
                    rotation = 0
            }

            MouseArea {
                id: submitMouse
                anchors.fill: parent
                enabled: root.hasText && !root.authenticating
                cursorShape: Qt.PointingHandCursor
                // Same path as pressing Enter.
                onClicked: passwordInput.accepted()
            }
        }
    }

    Text {
        id: hintLabel
        anchors.top: pill.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.hint
        color: root.hintColor
        font.family: root.fontFamily
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
        opacity: root.hint !== "" ? 0.95 : 0
        // Reserve the line so the pill never jumps when a hint appears.
        height: Math.max(implicitHeight, Styling.fontSize(-1) + 6)

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        layer.enabled: true
        layer.effect: LockTextShadow {
            shadowColor: root.fill
        }
    }
}
