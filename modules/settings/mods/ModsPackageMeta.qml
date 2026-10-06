pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel

// Package metadata of the selected mod: author, license, source, page,
// revision, load order (move up/down), permissions, required commands,
// conflicts, required mods (install them) and the affected files.
ColumnLayout {
    id: meta

    required property var mod
    property bool filesExpanded: false

    readonly property var files: meta.mod?.affectedFiles ?? []
    readonly property var deps: meta.mod?.dependencyState ?? []
    readonly property int order: meta.mod?.order ?? 0

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing - 2

    ModsLinkRow {
        visible: (meta.mod?.author ?? "") !== ""
        label: I18n.t("mods.author")
        value: meta.mod?.author ?? ""
        url: meta.mod?.authorUrl ?? ""
    }

    ModsMetaRow {
        visible: (meta.mod?.license ?? "") !== ""
        label: I18n.t("mods.license")
        value: meta.mod?.license ?? ""
    }

    ModsLinkRow {
        label: I18n.t("mods.source")
        value: meta.mod?.source ?? I18n.t("mods.unknown")
        url: meta.mod?.source ?? ""
        mono: true
    }

    ModsLinkRow {
        visible: (meta.mod?.homepage ?? "") !== ""
        label: I18n.t("mods.homepage")
        value: meta.mod?.homepage ?? ""
        url: meta.mod?.homepage ?? ""
        mono: true
    }

    ModsMetaRow {
        visible: (meta.mod?.revision ?? "") !== ""
        label: I18n.t("mods.revision")
        value: ModsModel.shortRevision(meta.mod?.revision)
        mono: true
    }

    ModsMetaRow {
        label: I18n.t("mods.load_order")
        value: String(meta.order + 1)

        PillButton {
            kind: "ghost"
            icon: "arrowUp"
            text: I18n.t("mods.move_up")
            enabled: !ModsService.busy && meta.order > 0
            onClicked: ModsService.move(meta.mod.id, -1)
        }

        PillButton {
            kind: "ghost"
            icon: "arrowDown"
            text: I18n.t("mods.move_down")
            enabled: !ModsService.busy && meta.order < (ModsService.mods ?? []).length - 1
            onClicked: ModsService.move(meta.mod.id, 1)
        }
    }

    ModsMetaRow {
        visible: (meta.mod?.permissions ?? []).length > 0
        label: I18n.t("mods.permissions")
        value: ModsModel.joinList(meta.mod?.permissions)
    }

    ModsMetaRow {
        visible: (meta.mod?.commands ?? []).length > 0
        label: I18n.t("mods.requirements")
        value: ModsModel.joinList(meta.mod?.commands)
        mono: true
    }

    ModsMetaRow {
        visible: (meta.mod?.conflicts ?? []).length > 0
        label: I18n.t("mods.conflicts")
        value: ModsModel.joinList(meta.mod?.conflicts)
        mono: true
    }

    Repeater {
        model: meta.deps

        delegate: ModsMetaRow {
            id: depRow
            required property var modelData
            required property int index
            label: index === 0 ? I18n.t("mods.required_mods") : ""
            value: modelData.id
            mono: true

            Text {
                text: I18n.t(ModsModel.dependencyKey(depRow.modelData))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: depRow.modelData.enabled ? Colors.success : Colors.warning
            }
        }
    }

    PillButton {
        Layout.leftMargin: Metrics.menuW - 40 + Metrics.spacing + 2
        visible: meta.deps.length > 0 && !ModsModel.dependenciesReady(meta.mod)
        kind: "filled"
        text: I18n.t("mods.install_dependencies")
        enabled: !ModsService.busy
        onClicked: ModsService.installDependencies(meta.mod.id)
    }

    ModsMetaRow {
        label: I18n.t("mods.affected_files")
        value: meta.files.length === 0 ? I18n.t("mods.none") : ""

        PillButton {
            visible: meta.files.length > 0
            kind: "ghost"
            icon: meta.filesExpanded ? "caretDown" : "caretRight"
            text: meta.filesExpanded ? I18n.t("mods.hide_files") : I18n.t("mods.show_files", String(meta.files.length))
            onClicked: meta.filesExpanded = !meta.filesExpanded
        }
    }

    StyledRect {
        visible: meta.filesExpanded && meta.files.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Metrics.menuW - 40 + Metrics.spacing + 2
        Layout.preferredHeight: fileList.implicitHeight + Metrics.spacing * 2
        variant: "common"
        radius: Styling.radius(-2)
        enableShadow: false

        Column {
            id: fileList
            x: Metrics.spacing
            y: Metrics.spacing
            width: parent.width - Metrics.spacing * 2
            spacing: 2

            Repeater {
                model: meta.files

                delegate: Text {
                    required property string modelData
                    width: fileList.width
                    text: modelData
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    elide: Text.ElideLeft
                }
            }
        }
    }
}
