import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui

// "Skip setup?" confirmation drawn over the wizard card (never a one-key
// permanent dismissal). Shown while `wizard.skipRequested`; "Keep going"
// closes it, "Skip" ends the wizard (OnboardingState.finish).
Item {
    id: root

    required property var wizard
    readonly property bool shown: wizard.skipRequested

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    onShownChanged: if (shown)
        keep.forceActiveFocus()

    // dim the card and swallow clicks behind the dialog
    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(10)
        color: Ui.alpha(Colors.background, 0.7)
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.wizard.skipRequested = false
    }

    StyledRect {
        id: panel
        objectName: "skipConfirmPanel"
        variant: "pane"
        enableShadow: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, Math.round(Styling.fontSize(0) * 28))
        height: col.implicitHeight + Math.round(Styling.fontSize(0) * 3.2)
        radius: Styling.radius(6)
        scale: root.shown ? 1 : 0.94
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
                easing.overshoot: 1.2
            }
        }

        // swallow clicks on the dialog itself
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Math.round(Styling.fontSize(0) * 1.6)
            spacing: Math.round(Styling.fontSize(0) * 0.9)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(Styling.fontSize(0) * 3.4)
                height: width
                radius: width / 2
                color: Ui.alpha(Colors.primary, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: Icons.forward ?? ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(4)
                    color: Colors.primary
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("onboarding.skip.title")
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(6)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("onboarding.skip.body")
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                topPadding: Math.round(Styling.fontSize(0) * 0.4)
                NavButton {
                    id: keep
                    objectName: "skipKeepGoing"
                    kind: "filled"
                    text: I18n.t("onboarding.skip.keep")
                    onClicked: root.wizard.skipRequested = false
                }
                NavButton {
                    objectName: "skipConfirm"
                    kind: "ghost"
                    text: I18n.t("onboarding.skip.confirm")
                    onClicked: root.wizard.finish()
                }
            }
        }
    }
}
