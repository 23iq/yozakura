pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui
import "OnboardingModel.js" as Model

// AI agents (detected CLI agents and Ollama; toggles write ai.agents.<id>)
// and local voice input (whisper.cpp: status, toggle, or a one-click setup
// running scripts/voice_setup.sh with live progress).
Item {
    id: root

    property OnboardingState wizard

    readonly property var detected: wizard ? wizard.detected : Model.parseDetect("")
    readonly property bool aiOn: wizard ? wizard.get("ai.enabled") !== false : true
    readonly property int gap: Math.round(Styling.fontSize(0) * 1.6)

    function installed(id) {
        return detected.agents[id] !== undefined;
    }

    Row {
        anchors.fill: parent
        spacing: root.gap

        Column {
            width: (parent.width - root.gap) / 2
            spacing: 8

            SectionLabel {
                width: parent.width
                icon: "robot"
                text: I18n.t("onboarding.ai.agents")
                hint: I18n.t("onboarding.ai.agents.desc")
            }

            ChoiceRow {
                objectName: "aiMaster"
                width: parent.width
                mode: "toggle"
                icon: "sparkle"
                title: I18n.t("onboarding.ai.enable")
                subtitle: I18n.t("onboarding.ai.enable.desc")
                checked: root.aiOn
                onToggled: v => root.wizard.set("ai.enabled", v)
            }

            Repeater {
                model: Model.AGENTS
                delegate: ChoiceRow {
                    id: agentRow
                    required property var modelData
                    readonly property bool present: root.installed(modelData.id)
                    width: parent.width
                    mode: modelData.config !== "" && present ? "toggle" : "none"
                    enabled: root.aiOn
                    dimmed: !present || !root.aiOn
                    icon: modelData.icon
                    title: modelData.label
                    badge: present ? I18n.t("onboarding.installed") : I18n.t("onboarding.not_found")
                    badgeOk: present
                    subtitle: present ? (modelData.config === "" ? I18n.t("onboarding.ai.ollama.desc") : root.detected.agents[modelData.id]) : I18n.t(modelData.install)
                    checked: modelData.config !== "" && root.wizard && root.wizard.get("ai.agents." + modelData.config + ".enabled") !== false
                    onToggled: v => root.wizard.set("ai.agents." + agentRow.modelData.config + ".enabled", v)
                }
            }
        }

        Column {
            width: (parent.width - root.gap) / 2
            spacing: 8

            SectionLabel {
                width: parent.width
                icon: "mic"
                text: I18n.t("onboarding.voice.title")
                hint: I18n.t("onboarding.voice.desc")
            }

            ChoiceRow {
                objectName: "voiceToggle"
                width: parent.width
                mode: root.wizard && root.wizard.voiceInstalled ? "toggle" : "none"
                dimmed: !(root.wizard && root.wizard.voiceInstalled)
                icon: "waveform"
                title: I18n.t("onboarding.voice.whisper")
                badge: root.wizard && root.wizard.voiceInstalled ? I18n.t("onboarding.installed") : I18n.t("onboarding.not_installed")
                badgeOk: root.wizard && root.wizard.voiceInstalled
                subtitle: root.wizard && root.wizard.voiceInstalled ? I18n.t("onboarding.voice.ready") : (root.detected.cuda ? I18n.t("onboarding.voice.gpu") : I18n.t("onboarding.voice.cpu"))
                checked: root.wizard && root.wizard.get("voice.enabled") !== false
                onToggled: v => root.wizard.set("voice.enabled", v)
            }

            // Setup job: offer, progress, result.
            Rectangle {
                id: setup
                objectName: "voiceSetup"
                visible: root.wizard && (!root.wizard.voiceInstalled || root.wizard.voiceStatus !== "")
                width: parent.width
                height: setupCol.implicitHeight + 28
                radius: Styling.radius(2)
                color: Ui.alpha(Colors.overBackground, 0.035)

                readonly property string status: root.wizard ? root.wizard.voiceStatus : ""

                Column {
                    id: setupCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: {
                            switch (setup.status) {
                            case "running":
                                return I18n.t("onboarding.voice.running");
                            case "done":
                                return I18n.t("onboarding.voice.done");
                            case "failed":
                                return I18n.t("onboarding.voice.failed");
                            case "cancelled":
                                return I18n.t("onboarding.voice.cancelled");
                            default:
                                return I18n.t("onboarding.voice.offer");
                            }
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: setup.status === "failed" ? Colors.error : Colors.overBackground
                    }

                    // progress bar
                    Item {
                        visible: setup.status === "running" || setup.status === "done"
                        width: parent.width
                        height: 6
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Ui.alpha(Colors.overBackground, 0.1)
                        }
                        Rectangle {
                            width: parent.width * (root.wizard ? root.wizard.voiceProgress : 0)
                            height: parent.height
                            radius: height / 2
                            color: Colors.primary
                            Behavior on width {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration * 2
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Text {
                        visible: text !== "" && setup.status !== ""
                        width: parent.width
                        text: root.wizard ? root.wizard.voiceLine : ""
                        elide: Text.ElideMiddle
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-3)
                        color: Colors.outline
                    }

                    Row {
                        spacing: 8
                        NavButton {
                            objectName: "voiceSetupStart"
                            visible: setup.status !== "running" && setup.status !== "done"
                            kind: "tonal"
                            icon: "downloadSimple"
                            text: setup.status === "" ? I18n.t("onboarding.voice.install") : I18n.t("onboarding.voice.retry")
                            onClicked: root.wizard.startVoiceSetup()
                        }
                        NavButton {
                            visible: setup.status === "running"
                            kind: "ghost"
                            icon: "xCircle"
                            text: I18n.t("onboarding.cancel")
                            onClicked: root.wizard.cancelVoiceSetup()
                        }
                    }
                }
            }
        }
    }
}
