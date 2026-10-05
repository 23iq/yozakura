import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities

// Recording (with stop), microphone (apps + mute), camera and screen
// sharing (apps).
NotchPanel {
    id: panel

    readonly property bool recording: ActivityService.privacy.some(a => a.source === "recording")

    implicitHeight: panel.padding * 2 + title.implicitHeight + panel.unit * 2 + list.implicitHeight

    NotchPanelTitle {
        id: title
        x: panel.padding
        y: panel.padding
        width: parent.width - panel.padding * 2
        unit: panel.unit
        icon: panel.recording ? Icons.recordScreen : Icons.mic
        text: I18n.t("activities.privacy")
        accent: panel.recording ? Colors.red : Colors.yellow
    }

    NotchActivitiesSection {
        id: list
        x: panel.padding
        y: title.y + title.implicitHeight + panel.unit * 2
        width: parent.width - panel.padding * 2
        height: implicitHeight
        maxRows: panel.maxRows > 0 ? panel.maxRows : 5
        activities: ActivityService.privacy
        screenName: panel.screenName
    }
}
