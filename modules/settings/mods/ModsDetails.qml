import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel
import "../Ui.js" as Ui
import qs.modules.components.kit

// Details of the selected mod: name, id/version and state, description,
// package problems, metadata, its own settings and the actions (enable or
// disable, update, remove with a second confirming click).
ModsCard {
    id: details

    required property var mod
    property bool removeArmed: false
    property alias filesExpanded: packageMeta.filesExpanded
    signal enableRequested

    readonly property string problem: details.mod?.error || details.mod?.compatibilityError || ""

    readonly property string modId: details.mod?.id ?? ""

    // Re-arming and folding start over for every mod (not on every refresh,
    // which replaces the mod objects).
    onModIdChanged: {
        details.removeArmed = false;
        details.filesExpanded = false;
    }

    RowLayout {
        width: parent.width
        spacing: Metrics.spacing + 2

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Space.xs / 2

            KitText {
                role: "title"
                Layout.fillWidth: true
                text: details.mod?.name ?? ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            KitText {
                role: "caption"
                Layout.fillWidth: true
                text: (details.mod?.id ?? "") + " · " + (details.mod?.version ?? "")
                font.family: Config.theme.monoFont
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: stateChip.implicitWidth + Metrics.padding + 4
            implicitHeight: Metrics.badgeHeight + 2
            variant: "focus"
            radius: height / 2
            enableShadow: false

            KitText {
                id: stateChip
                role: "caption"
                anchors.centerIn: parent
                text: I18n.t(ModsModel.stateKey(details.mod))
                font.weight: Font.Medium
                color: Colors[ModsModel.stateTone(details.mod)]
            }
        }
    }

    KitText {
        role: "secondary"
        width: parent.width
        visible: (details.mod?.description ?? "") !== ""
        text: details.mod?.description ?? ""
        color: Colors.overBackground
        wrapMode: Text.Wrap
    }

    KitText {
        role: "caption"
        width: parent.width
        visible: details.problem !== ""
        text: I18n.t("mods.package_status") + ": " + (details.problem || I18n.t("mods.unknown_error"))
        color: Colors.error
        wrapMode: Text.WrapAnywhere
    }

    KitText {
        role: "caption"
        width: parent.width
        visible: (details.mod?.untestedMessage ?? "") !== ""
        text: I18n.t("mods.untested_base", details.mod?.untestedMessage ?? "")
        color: Colors.warning
        wrapMode: Text.Wrap
    }

    KitText {
        role: "caption"
        width: parent.width
        visible: (details.mod?.unknownFields ?? []).length > 0
        text: I18n.t("mods.unknown_fields", ModsModel.joinList(details.mod?.unknownFields))
        color: Colors.warning
        wrapMode: Text.Wrap
    }

    Divider {
        width: parent.width
    }

    ModsPackageMeta {
        id: packageMeta
        mod: details.mod
    }

    Divider {
        visible: Look.dividers && (settingsForm.visible)
        width: parent.width
    }

    ModsSettingsForm {
        id: settingsForm
        visible: details.mod?.hasSettings ?? false
        modId: details.mod?.id ?? ""
    }

    Divider {
        width: parent.width
    }

    RowLayout {
        width: parent.width
        spacing: Metrics.spacing

        PillButton {
            kind: details.mod?.enabled ? "tonal" : "filled"
            text: details.mod?.enabled ? I18n.t("mods.disable") : I18n.t("mods.enable")
            enabled: !ModsService.busy && ModsModel.canToggle(details.mod, ModsService.bypassVersionCheck)
            onClicked: {
                if (details.mod.enabled)
                    ModsService.setEnabled(details.mod.id, false);
                else
                    details.enableRequested();
            }
        }

        PillButton {
            icon: "arrowsClockwise"
            text: I18n.t("mods.update")
            enabled: !ModsService.busy
            onClicked: ModsService.update(details.mod.id, details.mod.enabled)
        }

        Item {
            Layout.fillWidth: true
        }

        PillButton {
            kind: details.removeArmed ? "filled" : "ghost"
            icon: "trash"
            text: details.removeArmed ? I18n.t("mods.confirm_remove") : I18n.t("mods.remove")
            enabled: !ModsService.busy
            onClicked: {
                if (!details.removeArmed) {
                    details.removeArmed = true;
                    return;
                }
                details.removeArmed = false;
                ModsService.remove(details.mod.id, details.mod.enabled);
            }
        }
    }
}
