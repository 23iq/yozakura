import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities
import "../../../services/activities/TransferModel.js" as TransferModel

// Downloads, copies, updates and syncs: grouped by source, each with icon,
// name, progress, sizes · speed and ETA/state, and its actions. The title
// carries the combined progress and speed.
NotchPanel {
    id: panel

    readonly property var summary: TransferModel.summarize(ActivityService.transfers)
    readonly property string summaryText: {
        const s = panel.summary;
        const parts = [];
        if (s.active > 0 && s.progress >= 0)
            parts.push(TransferModel.formatPercent(s.progress));
        if (ActivityService.showSpeed && s.rate > 0)
            parts.push(TransferModel.formatRate(s.rate));
        if (s.eta >= 0)
            parts.push(TransferModel.formatEta(s.eta) + " " + I18n.t("activities.left"));
        return parts.join(" · ");
    }

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        NotchPanelTitle {
            width: parent.width
            text: I18n.t("activities.downloads") + (ActivityService.transfers.length > 1 ? " · " + ActivityService.transfers.length : "")
            summary: panel.summaryText
        }

        NotchActivitiesSection {
            width: parent.width
            height: implicitHeight
            maxRows: panel.maxRows > 0 ? panel.maxRows : 5
            transfers: ActivityService.transfers
            screenName: panel.screenName
        }
    }
}
