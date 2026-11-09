pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.settings.store
import qs.modules.aicenter.common
import qs.modules.components.kit

// Task settings of the project (tasks.project.get/set): check command
// (with the auto-detected suggestion), fix attempts, merge mode, check
// timeout; plus the global queue knobs (ai.tasks.maxParallel,
// ai.tasks.fallbackAgent). Every change is saved at once.
IconButton {
    id: root
    size: "xs"
    objectName: "projectSettings"

    property string dir: ""
    readonly property var info: TasksService.projects[root.dir] || null
    property string error: ""

    function set(patch) {
        root.error = "";
        TasksService.setProject(Object.assign({
            "dir": root.dir
        }, patch), (res, error) => root.error = error || "");
    }

    icon: Icons.faders
    tooltip: I18n.t("ai.tasks.project_settings")
    active: popup.opened
    onClicked: {
        TasksService.refreshProject(root.dir);
        popup.open();
    }

    Popup {
        id: popup
        y: parent.height + Space.xs
        x: Math.min(0, (root.parent ? root.parent.width : 0) - root.x - width)
        // Never wider than the project bar (the compact AI bar).
        width: Math.min(400, root.parent ? root.parent.width : 400)
        padding: Space.m
        background: StyledRect {
            variant: "popup"
            radius: Look.radius("control")
            enableShadow: true
        }
        contentItem: ColumnLayout {
            spacing: Space.s

            AiText {
                role: "caption"
                text: I18n.t("ai.tasks.check_command")
                font.weight: Font.DemiBold
                color: Type.text
            }
            TextField {
                id: check
                objectName: "checkCommand"
                Layout.fillWidth: true
                text: root.info && root.info.checkCommand !== null && root.info.checkCommand !== undefined ? root.info.checkCommand : ""
                placeholderText: root.info && root.info.suggestedCheck ? I18n.t("ai.tasks.check_auto").replace("%1", root.info.suggestedCheck) : I18n.t("ai.tasks.check_none")
                placeholderTextColor: Colors.outline
                color: Colors.overSurface
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.monoSize("caption")
                background: StyledRect {
                    variant: "common"
                    radius: Look.radius("control")
                }
                onEditingFinished: if (root.info && text !== (root.info.checkCommand || ""))
                    root.set(text.trim() ? {
                        "checkCommand": text.trim()
                    } : {
                        "resetCheck": true
                    })
            }
            Flow {
                Layout.fillWidth: true
                spacing: Space.s
                Chip {
                    visible: !!root.info && !!root.info.suggestedCheck
                    icon: Icons.sparkle
                    text: I18n.t("ai.tasks.use_detected").replace("%1", root.info ? root.info.suggestedCheck || "" : "")
                    mono: true
                    quiet: true
                    onClicked: root.set({
                        "resetCheck": true
                    })
                }
                Chip {
                    text: I18n.t("ai.tasks.no_check")
                    active: !!root.info && root.info.checkCommand === ""
                    quiet: true
                    onClicked: root.set({
                        "checkCommand": ""
                    })
                }
            }
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: root.info ? I18n.t("ai.tasks.check_effective").replace("%1", root.info.effectiveCheck || I18n.t("ai.tasks.no_check")) : ""
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Space.s
                rowSpacing: Space.s
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.max_attempts")
                    color: Type.text
                }
                SpinBox {
                    objectName: "maxAttempts"
                    from: 0
                    to: 10
                    value: root.info?.maxAttempts ?? 2
                    onValueModified: root.set({
                        "maxAttempts": value
                    })
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.check_timeout")
                    color: Type.text
                }
                SpinBox {
                    from: 30
                    to: 7200
                    stepSize: 30
                    value: root.info?.checkTimeout ?? 600
                    onValueModified: root.set({
                        "checkTimeout": value
                    })
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.merge_mode")
                    color: Type.text
                }
                Row {
                    spacing: Space.xs
                    Repeater {
                        model: ["squash", "merge"]
                        delegate: Chip {
                            id: mode
                            required property string modelData
                            text: I18n.t("prefs.ai.tasks.merge_" + mode.modelData)
                            active: !!root.info && root.info.mergeMode === mode.modelData
                            onClicked: root.set({
                                "mergeMode": mode.modelData
                            })
                        }
                    }
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.max_parallel")
                    color: Type.text
                }
                SpinBox {
                    from: 1
                    to: 8
                    value: Config.ai.tasks.maxParallel
                    onValueModified: SettingsStore.set("ai.tasks.maxParallel", value)
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.fallback")
                    color: Type.text
                }
                Row {
                    spacing: Space.xs
                    Repeater {
                        model: ["", "claude", "codex", "opencode"]
                        delegate: Chip {
                            id: fb
                            required property string modelData
                            text: fb.modelData ? I18n.t("prefs.ai.tasks.agent_" + fb.modelData) : I18n.t("prefs.ai.tasks.fallback_none")
                            active: Config.ai.tasks.fallbackAgent === fb.modelData
                            onClicked: SettingsStore.set("ai.tasks.fallbackAgent", fb.modelData)
                        }
                    }
                }
            }
            AiText {
                role: "caption"
                Layout.fillWidth: true
                visible: root.error.length > 0
                text: root.error
                wrapMode: Text.Wrap
                color: Type.danger
            }
        }
    }
}
