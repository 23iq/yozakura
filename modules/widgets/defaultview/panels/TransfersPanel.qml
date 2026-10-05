import QtQuick
import qs.modules.theme
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

    implicitHeight: panel.padding * 2 + title.implicitHeight + panel.unit * 2 + list.implicitHeight

    NotchPanelTitle {
        id: title
        x: panel.padding
        y: panel.padding
        width: parent.width - panel.padding * 2
        unit: panel.unit
        icon: Icons.downloadSimple
        text: I18n.t("activities.downloads") + (ActivityService.transfers.length > 1 ? "  " + ActivityService.transfers.length : "")
        summary: panel.summaryText
        accent: panel.summary.state === "failed" ? Colors.error : Colors.primary
    }

    NotchActivitiesSection {
        id: list
        x: panel.padding
        y: title.y + title.implicitHeight + panel.unit * 2
        width: parent.width - panel.padding * 2
        height: implicitHeight
        maxRows: panel.maxRows > 0 ? panel.maxRows : 5
        transfers: ActivityService.transfers
        screenName: panel.screenName
    }
}
