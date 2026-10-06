import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel
import "../Ui.js" as Ui

// Trust prompt. Installing and enabling both bring somebody else's code
// into the shell, so both say whose code it is before it happens.
// `kind` "install" | "enable" ("" = closed); `confirmed()` runs it.
Item {
    id: dialog

    property string kind: ""
    property var mod: null
    property string source: ""
    signal confirmed
    signal cancelled

    readonly property bool enabling: dialog.kind === "enable"

    visible: dialog.kind !== ""
    z: 50

    Keys.onEscapePressed: dialog.cancelled()
    onVisibleChanged: {
        if (visible)
            card.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: dialog.cancelled()
        }
    }

    StyledRect {
        id: card
        anchors.centerIn: parent
        width: Math.min(dialog.width - 48, Metrics.sheetW + 40)
        height: confirmColumn.implicitHeight + 36
        variant: "popup"
        radius: Styling.radius(4)
        focus: true

        Keys.onEscapePressed: dialog.cancelled()

        // Swallows clicks so they do not reach the scrim.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: confirmColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: Metrics.spacing + 2

            Text {
                Layout.fillWidth: true
                text: dialog.enabling ? I18n.t("mods.confirm_enable_title") : I18n.t("mods.confirm_install_title")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.DemiBold
                color: Colors.overBackground
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: dialog.enabling ? I18n.t("mods.confirm_enable_body") : I18n.t("mods.confirm_install_body")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Ui.alpha(Colors.outlineVariant, 0.45)
            }

            ModsLinkRow {
                visible: (dialog.mod?.author ?? "") !== ""
                label: I18n.t("mods.author")
                value: dialog.mod?.author ?? ""
                url: dialog.mod?.authorUrl ?? ""
            }

            ModsMetaRow {
                visible: (dialog.mod?.license ?? "") !== ""
                label: I18n.t("mods.license")
                value: dialog.mod?.license ?? ""
            }

            ModsLinkRow {
                visible: dialog.source !== ""
                label: I18n.t("mods.source")
                value: dialog.source
                url: dialog.source
                mono: true
            }

            ModsLinkRow {
                visible: (dialog.mod?.homepage ?? "") !== ""
                label: I18n.t("mods.homepage")
                value: dialog.mod?.homepage ?? ""
                url: dialog.mod?.homepage ?? ""
                mono: true
            }

            ModsMetaRow {
                visible: (dialog.mod?.permissions ?? []).length > 0
                label: I18n.t("mods.permissions")
                value: ModsModel.joinList(dialog.mod?.permissions)
            }

            ModsMetaRow {
                visible: (dialog.mod?.affectedFiles ?? []).length > 0
                label: I18n.t("mods.affected_files")
                value: String((dialog.mod?.affectedFiles ?? []).length)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: Metrics.spacing

                Item {
                    Layout.fillWidth: true
                }

                PillButton {
                    kind: "ghost"
                    text: I18n.t("common.cancel")
                    onClicked: dialog.cancelled()
                }

                PillButton {
                    kind: "filled"
                    text: dialog.enabling ? I18n.t("mods.enable") : I18n.t("mods.install")
                    onClicked: dialog.confirmed()
                }
            }
        }
    }
}
