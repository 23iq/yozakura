import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel

// The most urgent ModsService state: an error, a stale generation (Rebuild),
// a pending restart (Restart now) or the last status message.
StyledRect {
    id: banner

    readonly property var info: ModsModel.bannerState({
        "errorMessage": ModsService.errorMessage,
        "generationCurrent": ModsService.generationCurrent,
        "generationError": ModsService.generationError,
        "restartRequired": ModsService.restartRequired,
        "modsEnabled": ModsService.modsEnabled,
        "statusMessageKey": ModsService.statusMessageKey,
        "statusMessage": ModsService.statusMessage
    })
    readonly property bool alarming: info.kind === "error" || info.kind === "rebuild"
    readonly property string message: {
        switch (info.kind) {
        case "rebuild":
            return I18n.t("mods.rebuild_required", info.text);
        case "restart":
            return I18n.t("mods.restart_required");
        case "restartBase":
            return I18n.t("mods.restart_base_required");
        case "key":
            return I18n.t(info.text);
        default:
            return info.text;
        }
    }

    visible: info.kind !== ""
    implicitHeight: statusRow.implicitHeight + Metrics.spacing * 2 + 2
    variant: alarming ? "focus" : "common"
    radius: Styling.radius(0)
    enableShadow: false

    RowLayout {
        id: statusRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.padding
        anchors.rightMargin: Metrics.spacing + 1
        spacing: Metrics.spacing + 2

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: banner.alarming ? Icons.alert : (ModsService.restartRequired ? Icons.arrowCounterClockwise : Icons.accept)
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
            color: banner.alarming ? Colors.error : Colors.overBackground
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: banner.message
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: banner.alarming ? Colors.error : Colors.overBackground
            wrapMode: Text.Wrap
        }

        PillButton {
            visible: !ModsService.generationCurrent
            enabled: !ModsService.busy
            kind: "filled"
            icon: "arrowCounterClockwise"
            text: I18n.t("mods.rebuild")
            onClicked: ModsService.rebuild()
        }

        PillButton {
            visible: ModsService.restartRequired
            enabled: !ModsService.busy
            kind: "filled"
            text: I18n.t("mods.restart_now")
            onClicked: ModsService.restart()
        }
    }
}
