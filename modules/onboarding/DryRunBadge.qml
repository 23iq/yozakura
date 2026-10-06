import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

// "DRY RUN — nothing is changed": shown on the wizard card header and the
// peek pill while the wizard runs as `<app> onboarding --dry-run` (DryRun).
StyledRect {
    id: root

    readonly property alias text: label.text

    objectName: "dryRunBadge"
    visible: DryRun.active
    variant: "error"
    radius: height / 2
    readonly property int padX: Math.round(Styling.fontSize(0) * 0.8)
    readonly property int padY: Math.round(Styling.fontSize(0) * 0.3)
    implicitWidth: label.implicitWidth + 2 * root.padX
    implicitHeight: label.implicitHeight + 2 * root.padY

    Text {
        id: label
        anchors.centerIn: parent
        text: I18n.t("onboarding.dryrun.badge")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.Black
        font.letterSpacing: 0.5
        color: root.item
    }
}
