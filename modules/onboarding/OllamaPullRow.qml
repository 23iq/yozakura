pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.extras
import qs.config
import "../settings/Ui.js" as Ui
import "OnboardingModel.js" as Model

// Under the Ollama card once it is installed: "Pull a model" with one chip
// per suggested model (OnboardingModel.OLLAMA_MODELS). A chip queues
// `ollama pull` in the backend (ExtrasService.ollamaPull) and then shows
// the download's progress, a check when done, or a retry when it failed.
// Models pulled before are found by probing the server (marked done); a
// server that does not answer gets a "start Ollama" hint.
StyledRect {
    id: root

    // providers.ollama.probe answer (null until it arrives)
    property var probe: null
    readonly property var pulled: Model.pulledModels(root.probe)
    readonly property bool stopped: !!root.probe && !root.probe.reachable

    Component.onCompleted: {
        const endpoint = Config.ai && Config.ai.ollama ? Config.ai.ollama.endpoint || "" : "";
        BackendService.call("providers.ollama.probe", {
            "endpoint": endpoint
        }, (res, err) => {
            if (!err && res)
                root.probe = res;
        });
    }

    variant: "common"
    enableShadow: false
    radius: Styling.radius(4)
    implicitHeight: col.implicitHeight + 28

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 10

        Row {
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.brain
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(2)
                color: Colors.primary
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: I18n.t("onboarding.ai.pull")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Text {
                    objectName: "pullHint"
                    text: root.stopped ? I18n.t("onboarding.ai.pull.start") : I18n.t("onboarding.ai.pull.desc")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: Model.OLLAMA_MODELS

                delegate: Item {
                    id: chip
                    required property var modelData
                    readonly property var pull: Model.pullState(ExtrasService.pullProgress(chip.modelData.id), ExtrasService.pulls[chip.modelData.id] !== undefined, root.pulled.includes(chip.modelData.id))
                    readonly property string phase: chip.pull.state
                    readonly property bool actionable: chip.phase === "idle" || chip.phase === "failed"
                    readonly property color tone: chip.phase === "failed" ? Colors.error : Colors.primary

                    objectName: "pullChip:" + chip.modelData.id
                    width: chipRow.implicitWidth + 28
                    height: 38
                    activeFocusOnTab: chip.actionable
                    Keys.onReturnPressed: chip.activate()
                    Keys.onSpacePressed: chip.activate()
                    Accessible.role: Accessible.Button
                    Accessible.name: chip.modelData.label

                    function activate() {
                        if (chip.actionable)
                            ExtrasService.ollamaPull(chip.modelData.id);
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.phase === "idle" ? Ui.alpha(Colors.overBackground, area.containsMouse ? 0.1 : 0.05) : Ui.alpha(chip.tone, chip.phase === "done" ? 0.18 : 0.1)
                        border.width: chip.activeFocus ? 2 : 1
                        border.color: chip.phase === "idle" ? Ui.alpha(Colors.outline, 0.35) : Ui.alpha(chip.tone, 0.5)
                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Motion.exit.duration
                            }
                        }
                    }

                    // download progress fills the chip from the left
                    ProgressTrack {
                        visible: chip.phase === "pulling"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 5
                        implicitHeight: 3
                        percent: chip.pull.percent
                    }

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                switch (chip.phase) {
                                case "done":
                                    return Icons.checkCircle;
                                case "failed":
                                    return Icons.arrowsClockwise;
                                case "pulling":
                                    return Icons.hourglass;
                                default:
                                    return Icons.downloadSimple;
                                }
                            }
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: chip.phase === "idle" ? Colors.overSurfaceVariant : chip.tone
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.label
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (chip.phase === "pulling")
                                    return chip.pull.percent >= 0 ? chip.pull.percent + "%" : I18n.t("onboarding.ai.pull.waiting");
                                if (chip.phase === "done")
                                    return I18n.t("onboarding.ai.pull.done");
                                if (chip.phase === "failed")
                                    return I18n.t("onboarding.ai.pull.retry");
                                return chip.modelData.size;
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: chip.phase === "failed" ? Colors.error : Colors.overSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: chip.actionable && !ExtrasService.offline
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chip.activate()
                    }
                }
            }
        }
    }
}
