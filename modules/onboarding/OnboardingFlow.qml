import QtQuick
import qs.modules.theme
import qs.modules.components
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

    readonly property int gutter: Math.round(Styling.fontSize(0) * 2.2)

    StyledRect {
        id: card
        objectName: "onboardingCard"
        variant: "popup"
        glassSurface: "popups"
        enableShadow: true
        anchors.centerIn: parent
        width: Math.min(1120, parent.width - Math.max(48, parent.width * 0.1))
        height: Math.min(780, parent.height - Math.max(48, parent.height * 0.1))
        radius: Styling.radius(10)
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
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
            anchors.margins: root.gutter
            height: Math.round(Styling.fontSize(0) * 2.4)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                SakuraLogo {
                    size: Math.round(Styling.fontSize(0) * 1.6)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Brand.displayName
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("onboarding.setup")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
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

            NavButton {
                objectName: "onboardingSkipAll"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.wizard.isLast
                kind: "ghost"
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
            anchors.leftMargin: root.gutter * 1.6
            anchors.rightMargin: root.gutter * 1.6
            anchors.topMargin: root.gutter
            anchors.bottomMargin: root.gutter * 0.6
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
                    from: root.wizard.direction * 48
                    to: 0
                    duration: Config.animDuration * 1.4
                    easing.type: Motion.emphasis.easing
                }
                NumberAnimation {
                    target: scaffold
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Config.animDuration * 1.4
                    easing.type: Motion.emphasis.easing
                }
            }
        }

        // ---- footer: back / continue --------------------------------------
        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.gutter
            height: next.implicitHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("onboarding.step_of", root.wizard.index + 1, root.wizard.count)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                NavButton {
                    objectName: "onboardingBack"
                    visible: !root.wizard.isFirst
                    kind: "ghost"
                    icon: "caretLeft"
                    text: I18n.t("onboarding.back")
                    onClicked: root.wizard.back()
                }
                NavButton {
                    id: next
                    objectName: "onboardingNext"
                    // the summary step has its own big "Start using" button
                    visible: !root.wizard.isLast
                    kind: "filled"
                    trailingIcon: "caretRight"
                    text: root.wizard.isFirst ? I18n.t("onboarding.get_started") : I18n.t("onboarding.continue")
                    onClicked: root.wizard.next()
                }
            }
        }
    }

    SkipConfirm {
        anchors.fill: card
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

    Timer {
        // first step once the card exists
        interval: 0
        running: true
        onTriggered: root.loadStep()
    }
}
