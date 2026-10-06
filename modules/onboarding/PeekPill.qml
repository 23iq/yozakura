import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// The wizard while peeking: a small floating pill (blossom, "Setup · step
// N/M", progress dots, "Back to setup"). Slides up and fades in; purely a
// view of OnboardingService (OnboardingPeekPill hosts it in a layer window).
Item {
    id: root

    property bool shown: false
    readonly property var wizard: OnboardingService.wizard

    readonly property int pad: Math.round(Styling.fontSize(0) * 0.9)
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledRect {
        id: pill
        objectName: "peekPill"
        variant: "popup"
        enableShadow: true
        radius: Math.min(height / 2, Styling.radius(8))
        implicitWidth: row.implicitWidth + root.pad * 2
        implicitHeight: row.implicitHeight + root.pad * 2
        opacity: root.shown ? 1 : 0
        y: root.shown ? 0 : Math.round(Styling.fontSize(0) * 2)
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 1.5
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 1.5
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(Styling.fontSize(0) * 0.9)

            SakuraLogo {
                anchors.verticalCenter: parent.verticalCenter
                size: Math.round(Styling.fontSize(0) * 2.2)
            }
            Text {
                objectName: "peekLabel"
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("onboarding.peek.label", root.wizard.index + 1, root.wizard.count)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }
            ProgressDots {
                anchors.verticalCenter: parent.verticalCenter
                count: root.wizard.count
                current: root.wizard.index
            }
            NavButton {
                objectName: "peekBack"
                anchors.verticalCenter: parent.verticalCenter
                kind: "filled"
                icon: "caretUp"
                text: I18n.t("onboarding.peek.back")
                onClicked: OnboardingService.peek = false
            }
        }
    }
}
