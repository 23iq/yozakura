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

// Task settings of the project (tasks.project.get/set): check command
// (with the auto-detected suggestion), fix attempts, merge mode, check
// timeout; plus the global queue knobs (ai.tasks.maxParallel,
// ai.tasks.fallbackAgent). Every change is saved at once.
IconButton {
    id: root
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

    glyph: Icons.faders
    tooltip: I18n.t("ai.tasks.project_settings")
    active: popup.opened
    onClicked: {
        TasksService.refreshProject(root.dir);
        popup.open();
    }

    Popup {
        id: popup
        y: parent.height + 4
        x: Math.min(0, (root.parent ? root.parent.width : 0) - root.x - width)
        width: 400
        padding: 12
        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(-2)
            enableShadow: true
        }
        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: I18n.t("ai.tasks.check_command")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurface
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
                font.pixelSize: BarLook.mono(-2)
                background: StyledRect {
                    variant: "common"
                    radius: Styling.radius(-4)
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
                spacing: 6
                Chip {
                    visible: !!root.info && !!root.info.suggestedCheck
                    glyph: Icons.sparkle
                    label: I18n.t("ai.tasks.use_detected").replace("%1", root.info ? root.info.suggestedCheck || "" : "")
                    mono: true
                    variant: "transparent"
                    onClicked: root.set({
                        "resetCheck": true
                    })
                }
                Chip {
                    label: I18n.t("ai.tasks.no_check")
                    active: !!root.info && root.info.checkCommand === ""
                    variant: active ? "primary" : "transparent"
                    onClicked: root.set({
                        "checkCommand": ""
                    })
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.info ? I18n.t("ai.tasks.check_effective").replace("%1", root.info.effectiveCheck || I18n.t("ai.tasks.no_check")) : ""
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.outline
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 8
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.max_attempts")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                SpinBox {
                    objectName: "maxAttempts"
                    from: 0
                    to: 10
                    value: root.info ? root.info.maxAttempts : 2
                    onValueModified: root.set({
                        "maxAttempts": value
                    })
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.check_timeout")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                SpinBox {
                    from: 30
                    to: 7200
                    stepSize: 30
                    value: root.info ? root.info.checkTimeout : 600
                    onValueModified: root.set({
                        "checkTimeout": value
                    })
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.merge_mode")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: ["squash", "merge"]
                        delegate: Chip {
                            id: mode
                            required property string modelData
                            label: I18n.t("prefs.ai.tasks.merge_" + mode.modelData)
                            active: !!root.info && root.info.mergeMode === mode.modelData
                            onClicked: root.set({
                                "mergeMode": mode.modelData
                            })
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.max_parallel")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                SpinBox {
                    from: 1
                    to: 8
                    value: Config.ai.tasks.maxParallel
                    onValueModified: SettingsStore.set("ai.tasks.maxParallel", value)
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("prefs.ai.tasks.fallback")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: ["", "claude", "codex", "opencode"]
                        delegate: Chip {
                            id: fb
                            required property string modelData
                            label: fb.modelData ? I18n.t("prefs.ai.tasks.agent_" + fb.modelData) : I18n.t("prefs.ai.tasks.fallback_none")
                            active: Config.ai.tasks.fallbackAgent === fb.modelData
                            onClicked: SettingsStore.set("ai.tasks.fallbackAgent", fb.modelData)
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.error.length > 0
                text: root.error
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.error
            }
        }
    }
}
