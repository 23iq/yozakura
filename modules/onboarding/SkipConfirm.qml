import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.services

// "Skip setup?" confirmation drawn over the wizard card (never a one-key
// permanent dismissal). Shown while `wizard.skipRequested`; "Keep going"
// closes it, "Skip" ends the wizard (OnboardingState.finish).
Item {
    id: root

    required property var wizard
    property real radius: Space.surfaceRadius
    readonly property bool shown: wizard.skipRequested

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    onShownChanged: if (shown)
        keep.forceActiveFocus()

    // Scrim: dims the card and swallows clicks behind the dialog.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colors.background, 0.7)
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.wizard.skipRequested = false
    }

    Surface {
        id: panel
        objectName: "skipConfirmPanel"
        enableShadow: true
        padding: Space.xl
        anchors.centerIn: parent
        width: Math.min(parent.width - Space.xxl * 2, Type.size("body") * 28)
        scale: root.shown ? 1 : 0.94
        Behavior on scale {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }

        // swallow clicks on the dialog itself
        MouseArea {
            width: col.width
            height: col.height
        }

        Column {
            id: col
            width: panel.width - panel.padding * 2
            spacing: Space.m

            Art {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Icons.forward ?? ""
            }

            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "title"
                text: I18n.t("onboarding.skip.title")
                wrapMode: Text.WordWrap
            }
            KitText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "secondary"
                text: I18n.t("onboarding.skip.body")
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Space.s
                topPadding: Space.s
                FocusChip {
                    id: keep
                    objectName: "skipKeepGoing"
                    primary: true
                    text: I18n.t("onboarding.skip.keep")
                    onClicked: root.wizard.skipRequested = false
                }
                FocusChip {
                    objectName: "skipConfirm"
                    text: I18n.t("onboarding.skip.confirm")
                    onClicked: root.wizard.finish()
                }
            }
        }
    }
}
