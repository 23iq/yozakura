import QtQuick
import qs.modules.services
import qs.modules.settings

// AI > Usage: where the usage history lives, the price override file and
// "clear history" (two-step: the button asks before deleting the ledger).
Item {
    id: root

    property var entry
    property bool confirming: false
    property string result: ""

    implicitHeight: column.implicitHeight

    Component.onCompleted: {
        UsageService.start();
        UsageService.refreshInfo();
    }

    Column {
        id: column

        width: parent.width
        spacing: 10

        StatusLine {
            width: parent.width
            icon: root.confirming ? "warning" : "info"
            tone: root.confirming ? "warn" : "muted"
            title: root.confirming ? I18n.t("prefs.ai.usage_clear_confirm") : I18n.t("prefs.ai.usage_where")
            detail: root.result || (root.confirming ? I18n.t("prefs.ai.usage_clear_confirm.desc") : (UsageService.info.ledgerDir || ""))
        }

        Row {
            spacing: 8

            PillButton {
                visible: !root.confirming
                kind: "ghost"
                icon: "fileText"
                text: I18n.t("ai.usage.edit_prices")
                enabled: !!UsageService.info.pricesOverride
                onClicked: UsageService.openPrices()
            }
            PillButton {
                objectName: "usageClear"
                visible: !root.confirming
                kind: "ghost"
                icon: "trash"
                text: I18n.t("prefs.ai.usage_clear")
                onClicked: {
                    root.result = "";
                    root.confirming = true;
                }
            }
            PillButton {
                visible: root.confirming
                kind: "ghost"
                text: I18n.t("common.cancel")
                onClicked: root.confirming = false
            }
            PillButton {
                objectName: "usageClearConfirm"
                visible: root.confirming
                kind: "filled"
                icon: "trash"
                text: I18n.t("prefs.ai.usage_clear_now")
                onClicked: {
                    root.confirming = false;
                    UsageService.clear((ok, err) => root.result = ok ? I18n.t("prefs.ai.usage_cleared") : String(err || ""));
                }
            }
        }
    }
}
