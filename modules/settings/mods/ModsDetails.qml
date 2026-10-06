import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel
import "../Ui.js" as Ui

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
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: details.mod?.name ?? ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.DemiBold
                color: Colors.overBackground
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (details.mod?.id ?? "") + " · " + (details.mod?.version ?? "")
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
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

            Text {
                id: stateChip
                anchors.centerIn: parent
                text: I18n.t(ModsModel.stateKey(details.mod))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Colors[ModsModel.stateTone(details.mod)]
            }
        }
    }

    Text {
        width: parent.width
        visible: (details.mod?.description ?? "") !== ""
        text: details.mod?.description ?? ""
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overBackground
        wrapMode: Text.Wrap
    }

    Text {
        width: parent.width
        visible: details.problem !== ""
        text: I18n.t("mods.package_status") + ": " + (details.problem || I18n.t("mods.unknown_error"))
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.error
        wrapMode: Text.WrapAnywhere
    }

    Text {
        width: parent.width
        visible: (details.mod?.untestedMessage ?? "") !== ""
        text: I18n.t("mods.untested_base", details.mod?.untestedMessage ?? "")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.warning
        wrapMode: Text.Wrap
    }

    Text {
        width: parent.width
        visible: (details.mod?.unknownFields ?? []).length > 0
        text: I18n.t("mods.unknown_fields", ModsModel.joinList(details.mod?.unknownFields))
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.warning
        wrapMode: Text.Wrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Ui.alpha(Colors.outlineVariant, 0.45)
    }

    ModsPackageMeta {
        id: packageMeta
        mod: details.mod
    }

    Rectangle {
        visible: settingsForm.visible
        width: parent.width
        height: 1
        color: Ui.alpha(Colors.outlineVariant, 0.45)
    }

    ModsSettingsForm {
        id: settingsForm
        visible: details.mod?.hasSettings ?? false
        modId: details.mod?.id ?? ""
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Ui.alpha(Colors.outlineVariant, 0.45)
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
