import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.editors
import qs.config
import "../Ui.js" as Ui

// Exclusive mode (Hyprland): the shell becomes the only one on the session.
// Off: what will change, with the real detected units/monitors, then a
// confirmation. On: where the backup is, what was disabled, and Restore.
Item {
    id: root

    property var entry
    // "" | "enable" | "restore": which confirmation is open
    property string confirming: ""
    readonly property var plan: ExclusiveService.plan ?? ({})
    readonly property var units: ExclusiveService.active ? (ExclusiveService.status.disabledUnits ?? []) : (root.plan.units ?? [])
    readonly property string userFile: root.plan.userFile ?? "user.lua"

    implicitHeight: column.implicitHeight

    Component.onCompleted: {
        ExclusiveService.refresh();
        ExclusiveService.loadPlan();
    }

    function importLine() {
        const mons = root.plan.monitors ?? [];
        const parts = [];
        if (mons.length > 0)
            parts.push(mons.join(", "));
        if (root.plan.keyboard)
            parts.push(I18n.t("prefs.exclusive.step.import.keyboard", root.plan.keyboard));
        return parts.length > 0 ? parts.join("  ·  ") : I18n.t("prefs.exclusive.step.import.none");
    }

    Column {
        id: column
        width: parent.width
        spacing: 16

        StatusLine {
            objectName: "exclusiveStatus"
            width: parent.width
            icon: ExclusiveService.active ? "shieldCheck" : "shield"
            tone: ExclusiveService.blocked !== "" ? "warn" : (ExclusiveService.active ? "ok" : "muted")
            title: ExclusiveService.active ? I18n.t("prefs.exclusive.on.title") : I18n.t("prefs.exclusive.off.title")
            detail: ExclusiveService.blocked !== "" ? ExclusiveService.blocked : (ExclusiveService.active ? I18n.t("prefs.exclusive.on.detail") : I18n.t("prefs.exclusive.off.detail"))

            PillButton {
                objectName: "exclusiveEnable"
                visible: !ExclusiveService.active && root.confirming === ""
                enabled: ExclusiveService.blocked === "" && !ExclusiveService.busy
                kind: "filled"
                icon: "lightning"
                text: I18n.t("prefs.exclusive.enable")
                onClicked: {
                    ExclusiveService.loadPlan();
                    root.confirming = "enable";
                }
            }
            PillButton {
                objectName: "exclusiveRestore"
                visible: ExclusiveService.active && root.confirming === ""
                enabled: !ExclusiveService.busy
                kind: "ghost"
                icon: "clockCounterClockwise"
                text: I18n.t("prefs.exclusive.restore")
                onClicked: root.confirming = "restore"
            }
        }

        Column {
            objectName: "exclusiveSteps"
            width: parent.width
            spacing: 14
            visible: !ExclusiveService.active

            ExclusiveStep {
                width: parent.width
                icon: "packageBox"
                title: I18n.t("prefs.exclusive.step.backup")
                detail: I18n.t("prefs.exclusive.step.backup.detail", root.plan.backupDir ?? "")
                mono: false
            }
            ExclusiveStep {
                width: parent.width
                icon: "fileText"
                title: I18n.t("prefs.exclusive.step.entry", root.plan.entry ?? "hyprland.lua")
                detail: I18n.t("prefs.exclusive.step.entry.detail", root.userFile)
            }
            ExclusiveStep {
                objectName: "unitsStep"
                width: parent.width
                icon: "plugsConnected"
                title: I18n.t("prefs.exclusive.step.units")
                detail: root.units.length > 0 ? root.units.join(", ") : I18n.t("prefs.exclusive.step.units.none")
                mono: root.units.length > 0
            }
            ExclusiveStep {
                objectName: "importStep"
                width: parent.width
                icon: "monitor"
                title: I18n.t("prefs.exclusive.step.import")
                detail: root.importLine()
            }
        }

        Column {
            objectName: "exclusiveActive"
            width: parent.width
            spacing: 14
            visible: ExclusiveService.active

            ExclusiveStep {
                width: parent.width
                icon: "packageBox"
                title: I18n.t("prefs.exclusive.active.backup")
                detail: ExclusiveService.status.backup ?? ""
                mono: true
            }
            ExclusiveStep {
                width: parent.width
                icon: "fileText"
                title: I18n.t("prefs.exclusive.active.tweaks", root.userFile)
                detail: I18n.t("prefs.exclusive.active.tweaks.detail", root.userFile)
            }
            ExclusiveStep {
                width: parent.width
                icon: "plugsConnected"
                title: I18n.t("prefs.exclusive.active.units")
                detail: root.units.length > 0 ? root.units.join(", ") : I18n.t("prefs.exclusive.step.units.none")
                mono: root.units.length > 0
            }
        }

        Text {
            visible: !ExclusiveService.active
            width: parent.width
            text: I18n.t("prefs.exclusive.safety")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }

        Rectangle {
            objectName: "exclusiveConfirm"
            visible: root.confirming !== ""
            width: parent.width
            height: confirmCol.implicitHeight + 28
            radius: Math.min(Styling.radius(2), 18)
            color: Ui.alpha(Colors.primary, 0.08)
            border.width: 1
            border.color: Ui.alpha(Colors.primary, 0.4)

            Column {
                id: confirmCol
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 10
                Text {
                    width: parent.width
                    text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.title") : I18n.t("prefs.exclusive.confirm.enable.title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.body", ExclusiveService.status.backup ?? "") : I18n.t("prefs.exclusive.confirm.enable.body")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.WrapAnywhere
                }
                Row {
                    spacing: 8
                    PillButton {
                        objectName: "exclusiveCancel"
                        kind: "ghost"
                        text: I18n.t("common.cancel")
                        onClicked: root.confirming = ""
                    }
                    PillButton {
                        objectName: "exclusiveConfirmButton"
                        kind: "filled"
                        enabled: !ExclusiveService.busy
                        icon: root.confirming === "restore" ? "clockCounterClockwise" : "lightning"
                        text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.go") : I18n.t("prefs.exclusive.confirm.enable.go")
                        onClicked: {
                            const run = root.confirming === "restore" ? ExclusiveService.restore : ExclusiveService.enable;
                            root.confirming = "";
                            run(() => ExclusiveService.loadPlan());
                        }
                    }
                }
            }
        }

        StatusLine {
            objectName: "exclusiveBusy"
            visible: ExclusiveService.busy
            width: parent.width
            icon: "hourglass"
            tone: "muted"
            title: I18n.t("prefs.exclusive.busy")
        }

        StatusLine {
            objectName: "exclusiveError"
            visible: ExclusiveService.error !== ""
            width: parent.width
            icon: "warning"
            tone: "error"
            title: I18n.t("prefs.exclusive.error")
            detail: ExclusiveService.error
        }

        StatusLine {
            objectName: "exclusiveRestored"
            visible: ExclusiveService.restored !== null && !ExclusiveService.active
            width: parent.width
            icon: "checkCircle"
            tone: "ok"
            title: I18n.t("prefs.exclusive.restored.title")
            detail: I18n.t("prefs.exclusive.restored.detail", ExclusiveService.restored ? ExclusiveService.restored.replaced : "")
        }
    }
}
