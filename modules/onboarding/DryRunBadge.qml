import QtQuick
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.globals

// "DRY RUN — nothing is changed": shown on the wizard card header and the
// peek pill while the wizard runs as `<app> onboarding --dry-run` (DryRun).
// A status badge in the theme's error variant (its ink is the variant's).
StyledRect {
    id: root

    readonly property alias text: label.text

    objectName: "dryRunBadge"
    visible: DryRun.active
    variant: "error"
    enableShadow: false
    radius: Look.chipRadius(height)
    implicitWidth: label.implicitWidth + Space.m * 2
    implicitHeight: label.implicitHeight + Space.xs * 2

    KitText {
        id: label
        anchors.centerIn: parent
        role: "label"
        text: I18n.t("onboarding.dryrun.badge")
        color: root.item
    }
}
