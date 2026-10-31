pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.components.kit

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

    readonly property real pillHeight: Space.controlM + Space.m
    readonly property real pillRadius: Space.round(pillHeight)
    readonly property color hintColor: errorShown ? errorColor : textColor

    field: passwordInput
    implicitWidth: Space.controlXL * 4 + Space.xl
    implicitHeight: pillHeight + Space.s + hintLabel.height

    LockGlass {
        id: pill
        width: parent.width
        height: root.pillHeight
        radius: root.pillRadius
        fill: root.fill
        ink: root.textColor
        strength: 0.62
        ringWidth: (root.showError || passwordInput.activeFocus) ? Space.hairline * 1.5 : Space.hairline
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
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }

        // Leading lock glyph
        Text {
            id: leadIcon
            anchors.left: parent.left
            anchors.leftMargin: Space.l
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.lock
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: root.showError ? root.errorColor : root.textColor
            opacity: root.showError ? 1 : 0.7

            Behavior on color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
        }

        TextField {
            id: passwordInput
            anchors.left: leadIcon.right
            anchors.leftMargin: Space.m
            anchors.right: capsIcon.visible ? capsIcon.left : submitButton.left
            anchors.rightMargin: Space.s
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
            font.pixelSize: root.hasText ? Type.size("title") : Type.size("body")
            font.letterSpacing: root.hasText ? Space.stroke : 0
            placeholderText: I18n.t("lockscreen.password")
            placeholderTextColor: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
            Keys.onReleased: event => root.observeKey(event)
        }

        // Caps lock indicator
        Text {
            id: capsIcon
            anchors.right: submitButton.left
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            visible: opacity > 0
            opacity: root.capsLock ? 1 : 0
            text: Icons.capsLock
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: root.accent

            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                }
            }
        }

        // Submit / progress button
        Item {
            id: submitButton
            anchors.right: parent.right
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            width: root.pillHeight - Space.l
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.hasText || root.authenticating ? root.accent : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                scale: submitMouse.pressed ? 0.9 : 1

                Behavior on color {
                    enabled: Motion.micro.duration > 0
                    ColorAnimation {
                        duration: Motion.micro.duration
                        easing.type: Motion.micro.easing
                    }
                }
                Behavior on scale {
                    enabled: Motion.spring.duration > 0
                    NumberAnimation {
                        duration: Motion.spring.duration
                        easing.type: Motion.spring.easing
                        easing.overshoot: Motion.spring.overshoot
                    }
                }
            }

            LockSpinner {
                id: submitGlyph
                anchors.centerIn: parent
                busy: root.authenticating
                color: root.hasText || root.authenticating ? root.overAccent : root.textColor
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

    KitText {
        id: hintLabel
        anchors.top: pill.bottom
        anchors.topMargin: Space.s
        anchors.horizontalCenter: parent.horizontalCenter
        role: "secondary"
        font.weight: Font.Medium
        text: root.hint
        color: root.hintColor
        opacity: root.hint !== "" ? 0.95 : 0
        // Reserve the line so the pill never jumps when a hint appears.
        height: Math.max(implicitHeight, Type.size("secondary") + Space.xs)

        Behavior on opacity {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
            }
        }

        layer.enabled: true
        layer.effect: LockTextShadow {
            shadowColor: root.fill
        }
    }
}
