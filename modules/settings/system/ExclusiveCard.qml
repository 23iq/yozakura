import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.editors
import qs.modules.components.kit

// Exclusive mode (Hyprland): the shell becomes the only one on the session.
// Off: one short sentence and a neutral "Make exclusive" (a risky change is
// never the accent); what will change, with the real detected units /
// monitors, folds out under "What changes"; then a confirmation whose
// button is the danger action. On: where the backup is, what was disabled,
// and Restore.
Item {
    id: root

    property var entry
    // "" | "enable" | "restore": which confirmation is open
    property string confirming: ""
    // the steps of "What changes" folded out
    property bool details: false
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
        spacing: Space.l

        StatusLine {
            objectName: "exclusiveStatus"
            width: parent.width
            icon: ExclusiveService.active ? "shieldCheck" : "shield"
            tone: ExclusiveService.blocked !== "" ? "warn" : (ExclusiveService.active ? "ok" : "muted")
            title: ExclusiveService.active ? I18n.t("prefs.exclusive.on.title") : I18n.t("prefs.exclusive.off.title")
            detail: ExclusiveService.blocked !== "" ? ExclusiveService.blocked : (ExclusiveService.active ? I18n.t("prefs.exclusive.on.detail") : I18n.t("prefs.exclusive.off.short"))

            PillButton {
                objectName: "exclusiveEnable"
                visible: !ExclusiveService.active && root.confirming === ""
                enabled: ExclusiveService.blocked === "" && !ExclusiveService.busy
                kind: "tonal"
                icon: "shield"
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

        // "What changes": the steps, folded away until asked for
        PillButton {
            objectName: "exclusiveDetails"
            visible: !ExclusiveService.active
            x: Math.max(0, Look.rowInset - Space.m)
            kind: "ghost"
            icon: root.details ? "caretUp" : "caretDown"
            text: I18n.t("prefs.exclusive.details")
            onClicked: root.details = !root.details
        }

        Column {
            objectName: "exclusiveSteps"
            width: parent.width
            spacing: Space.m
            visible: !ExclusiveService.active && (root.details || root.confirming === "enable")

            KitText {
                width: parent.width
                role: "secondary"
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.exclusive.off.detail")
            }

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
            spacing: Space.m
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

        KitText {
            visible: !ExclusiveService.active && (root.details || root.confirming === "enable")
            width: parent.width
            role: "caption"
            text: I18n.t("prefs.exclusive.safety")
            wrapMode: Text.WordWrap
        }

        // The confirmation: a group of its own (a hairline above in ink, a
        // card in glass, a tile in tiles) with the one primary action.
        Group {
            objectName: "exclusiveConfirm"
            labelRole: "group"
            visible: root.confirming !== ""
            width: parent.width
            divider: true

            KitText {
                width: parent.width
                role: "body"
                text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.title") : I18n.t("prefs.exclusive.confirm.enable.title")
                font.weight: Look.activeLabelWeight
                wrapMode: Text.WordWrap
            }
            KitText {
                width: parent.width
                role: "secondary"
                text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.body", ExclusiveService.status.backup ?? "") : I18n.t("prefs.exclusive.confirm.enable.body")
                wrapMode: Text.Wrap
            }
            Row {
                spacing: Space.s
                PillButton {
                    objectName: "exclusiveCancel"
                    kind: "ghost"
                    text: I18n.t("common.cancel")
                    onClicked: root.confirming = ""
                }
                // the risky step itself: the danger action (restore is the
                // safe way back: the plain primary)
                Chip {
                    objectName: "exclusiveConfirmButton"
                    primary: true
                    danger: root.confirming !== "restore"
                    enabled: !ExclusiveService.busy
                    icon: root.confirming === "restore" ? Icons.clockCounterClockwise : Icons.shieldWarning
                    text: root.confirming === "restore" ? I18n.t("prefs.exclusive.confirm.restore.go") : I18n.t("prefs.exclusive.confirm.enable.go")
                    Accessible.role: Accessible.Button
                    onClicked: {
                        const run = root.confirming === "restore" ? ExclusiveService.restore : ExclusiveService.enable;
                        root.confirming = "";
                        run(() => ExclusiveService.loadPlan());
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
