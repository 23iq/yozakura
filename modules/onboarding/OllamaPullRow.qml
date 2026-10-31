pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "OnboardingModel.js" as Model

// Under the Ollama card once it is installed: "Pull a model" with one chip
// per suggested model (OnboardingModel.OLLAMA_MODELS). A chip queues
// `ollama pull` in the backend (ExtrasService.ollamaPull) and then shows
// the download's progress, a check when done, or a retry when it failed.
// Models pulled before are found by probing the server (marked done); a
// server that does not answer gets a "start Ollama" hint.
Item {
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

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Space.m

        Row {
            spacing: Space.m
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.brain
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: Type.secondary
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                KitText {
                    role: "body"
                    font.weight: Look.labelWeight
                    text: I18n.t("onboarding.ai.pull")
                }
                KitText {
                    objectName: "pullHint"
                    role: "secondary"
                    text: root.stopped ? I18n.t("onboarding.ai.pull.start") : I18n.t("onboarding.ai.pull.desc")
                }
            }
        }

        Flow {
            width: parent.width
            spacing: Space.s

            Repeater {
                model: Model.OLLAMA_MODELS

                delegate: Item {
                    id: pullChip
                    required property var modelData
                    readonly property var pull: Model.pullState(ExtrasService.pullProgress(pullChip.modelData.id), ExtrasService.pulls[pullChip.modelData.id] !== undefined, root.pulled.includes(pullChip.modelData.id))
                    readonly property string phase: pullChip.pull.state
                    readonly property bool actionable: pullChip.phase === "idle" || pullChip.phase === "failed"

                    function activate() {
                        if (pullChip.actionable)
                            ExtrasService.ollamaPull(pullChip.modelData.id);
                    }

                    function status() {
                        switch (pullChip.phase) {
                        case "pulling":
                            return pullChip.pull.percent >= 0 ? pullChip.pull.percent + "%" : I18n.t("onboarding.ai.pull.waiting");
                        case "done":
                            return I18n.t("onboarding.ai.pull.done");
                        case "failed":
                            return I18n.t("onboarding.ai.pull.retry");
                        default:
                            return pullChip.modelData.size;
                        }
                    }

                    objectName: "pullChip:" + pullChip.modelData.id
                    implicitWidth: button.implicitWidth
                    implicitHeight: button.implicitHeight

                    FocusChip {
                        id: button
                        anchors.fill: parent
                        activeFocusOnTab: pullChip.actionable
                        icon: {
                            switch (pullChip.phase) {
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
                        text: pullChip.modelData.label + "  ·  " + pullChip.status()
                        Accessible.name: pullChip.modelData.label
                        onClicked: {
                            if (!ExtrasService.offline)
                                pullChip.activate();
                        }
                    }

                    // the download's progress along the chip's bottom edge
                    ProgressLine {
                        visible: pullChip.phase === "pulling"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Space.m
                        anchors.rightMargin: Space.m
                        anchors.bottomMargin: Space.xs
                        indeterminate: pullChip.pull.percent < 0
                        value: pullChip.pull.percent / 100
                    }
                }
            }
        }
    }
}
