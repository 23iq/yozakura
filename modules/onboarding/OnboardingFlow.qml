import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.globals
import qs.config
import "OnboardingSteps.js" as Steps

// The wizard card: brand + progress header, the current step (registry:
// OnboardingSteps.js) sliding in, and the Back / Continue footer. Hosted
// full-screen by OnboardingWindow; tests and renders load it directly.
Item {
    id: root

    // Owned by OnboardingService (persisted, resumable).
    readonly property var wizard: OnboardingService.wizard
    // false while the window steps aside for a keybind-tour panel.
    property bool shown: true

    signal closeRequested

    focus: true

    Connections {
        target: root.wizard
        function onFinished() {
            root.closeRequested();
        }
        function onSkipRequestedChanged() {
            if (!root.wizard.skipRequested)
                root.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        if (root.wizard.choices.initialPreset === undefined)
            root.wizard.remember("initialPreset", PresetsService.activePreset || "");
        root.wizard.initialPreset = root.wizard.choices.initialPreset;
        root.wizard.detect();
        // first step once the card exists
        Qt.callLater(root.loadStep);
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.wizard.skipRequested = !root.wizard.skipRequested;
            event.accepted = true;
        } else if (root.wizard.skipRequested) {
            // the confirmation owns the keyboard (Return acts on its buttons)
            return;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
            root.wizard.next();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) {
            root.wizard.back();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.AltModifier)) {
            root.wizard.next();
            event.accepted = true;
        }
    }

    Surface {
        id: card
        objectName: "onboardingCard"
        glassSurface: "popups"
        enableShadow: true
        padding: Space.xl
        anchors.centerIn: parent
        width: Math.min(Space.px(1120), parent.width - Math.max(Space.px(48), parent.width * 0.1))
        height: Math.min(Space.px(780), parent.height - Math.max(Space.px(48), parent.height * 0.1))
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
        Behavior on scale {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }

        // ---- header: brand, progress, skip ------------------------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Space.controlS

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                SakuraLogo {
                    size: Type.iconSize("title")
                    anchors.verticalCenter: parent.verticalCenter
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    text: Brand.displayName
                    font.weight: Font.DemiBold
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    color: Type.secondary
                    text: I18n.t("onboarding.setup")
                }
                DryRunBadge {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ProgressDots {
                objectName: "onboardingDots"
                anchors.centerIn: parent
                count: root.wizard.count
                current: root.wizard.index
                onPicked: i => root.wizard.go(i)
            }

            FocusChip {
                objectName: "onboardingSkipAll"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.wizard.isLast
                text: I18n.t("onboarding.skip_setup")
                onClicked: root.wizard.skipRequested = true
            }
        }

        // ---- current step ------------------------------------------------
        Item {
            id: stage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.leftMargin: Space.xl
            anchors.rightMargin: Space.xl
            anchors.topMargin: Space.xl
            anchors.bottomMargin: Space.l
            clip: true

            StepScaffold {
                id: scaffold
                width: parent.width
                height: parent.height
                step: root.wizard.step
                transform: Translate {
                    id: slide
                }

                Loader {
                    id: stepLoader
                    objectName: "stepLoader"
                    anchors.fill: parent
                    focus: true
                }
            }

            ParallelAnimation {
                id: enter
                NumberAnimation {
                    target: slide
                    property: "x"
                    from: root.wizard.direction * Space.xxl
                    to: 0
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
                NumberAnimation {
                    target: scaffold
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }

        // ---- footer: back / continue --------------------------------------
        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Space.controlS

            KitText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.muted
                text: I18n.t("onboarding.step_of", root.wizard.index + 1, root.wizard.count)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                FocusChip {
                    objectName: "onboardingBack"
                    visible: !root.wizard.isFirst
                    icon: Icons.caretLeft
                    text: I18n.t("onboarding.back")
                    onClicked: root.wizard.back()
                }
                FocusChip {
                    id: next
                    objectName: "onboardingNext"
                    // the summary step has its own big "Start using" button
                    visible: !root.wizard.isLast
                    primary: true
                    text: root.wizard.isFirst ? I18n.t("onboarding.get_started") : I18n.t("onboarding.continue")
                    onClicked: root.wizard.next()
                }
            }
        }
    }

    SkipConfirm {
        anchors.fill: card
        radius: card.radius
        wizard: root.wizard
    }

    function loadStep() {
        stepLoader.setSource(Qt.resolvedUrl(root.wizard.step.component), {
            "wizard": root.wizard
        });
        if (Config.animDuration > 0)
            enter.restart();
        root.forceActiveFocus();
    }

    Connections {
        target: root.wizard
        function onIndexChanged() {
            root.loadStep();
        }
    }
}
