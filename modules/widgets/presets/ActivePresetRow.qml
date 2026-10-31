import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../settings/presets/PresetStatusModel.js" as PresetStatusModel

// "Preset: Mine · 3 changes [Save]" in the preset switcher, shown while the
// live settings drifted from the active preset: Save stores them into the
// user's preset (undo in the notification); a built-in asks for a name
// (saveAsRequested, the gallery prompt).
Item {
    id: root

    readonly property string action: PresetStatusModel.primaryAction(PresetStatusService.status)

    signal saveAsRequested

    objectName: "activePresetRow"
    visible: root.action !== ""
    implicitHeight: root.visible ? Math.max(Space.chip, label.implicitHeight) : 0

    KitText {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        role: "caption"
        text: I18n.t("presets.status.label")
    }

    KitText {
        anchors.left: label.right
        anchors.leftMargin: Space.s
        anchors.right: save.left
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        role: "body"
        elide: Text.ElideRight
        text: PresetStatusService.active + " · " + I18n.tn("presets.status.changes", PresetStatusService.changed)
    }

    Chip {
        id: save
        objectName: "activePresetSave"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        primary: true
        icon: root.action === "save" ? Icons.check : Icons.plus
        text: root.action === "save" ? I18n.t("presets.status.save") : I18n.t("presets.status.save_as")
        onClicked: {
            if (root.action !== "save") {
                root.saveAsRequested();
                return;
            }
            PresetStatusService.save((ok, message, undo) => Notifications.notifyInternal({
                    "summary": ok ? message : I18n.t("common.error"),
                    "body": ok ? "" : message,
                    "appName": I18n.t("presets.status.label"),
                    "urgency": ok ? "normal" : "critical",
                    "actions": undo ? [
                        {
                            "identifier": "undo",
                            "text": I18n.t("prefs.presets.undo")
                        }
                    ] : [],
                    "actionHandlers": {
                        "undo": () => PresetStatusService.undoSave(undo)
                    }
                }));
        }
    }
}
