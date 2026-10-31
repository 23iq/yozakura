import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The wizard while peeking: a small floating pill (blossom, "Setup · step
// N/M", progress dots, "Back to setup"). Slides up and fades in; purely a
// view of OnboardingService (OnboardingPeekPill hosts it in a layer window).
Item {
    id: root

    property bool shown: false
    readonly property var wizard: OnboardingService.wizard

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Surface {
        id: pill
        objectName: "peekPill"
        floating: true
        padding: Space.s
        radius: Look.bigRadius(height)
        opacity: root.shown ? 1 : 0
        y: root.shown ? 0 : Space.xl
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
        Behavior on y {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }

        Row {
            spacing: Space.m
            leftPadding: Space.xs

            SakuraLogo {
                anchors.verticalCenter: parent.verticalCenter
                size: Space.chip
            }
            DryRunBadge {
                anchors.verticalCenter: parent.verticalCenter
            }
            KitText {
                objectName: "peekLabel"
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                font.weight: Font.DemiBold
                text: I18n.t("onboarding.peek.label", root.wizard.index + 1, root.wizard.count)
            }
            ProgressDots {
                anchors.verticalCenter: parent.verticalCenter
                count: root.wizard.count
                current: root.wizard.index
            }
            FocusChip {
                objectName: "peekBack"
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                icon: Icons.caretUp
                text: I18n.t("onboarding.peek.back")
                onClicked: OnboardingService.peek = false
            }
        }
    }
}
