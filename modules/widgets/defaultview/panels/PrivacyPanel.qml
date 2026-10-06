import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities

// Recording (with stop), microphone (apps + mute), camera and screen
// sharing (apps).
NotchPanel {
    id: panel

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        NotchPanelTitle {
            width: parent.width
            text: I18n.t("activities.privacy")
        }

        NotchActivitiesSection {
            width: parent.width
            height: implicitHeight
            maxRows: panel.maxRows > 0 ? panel.maxRows : 5
            activities: ActivityService.privacy
            screenName: panel.screenName
        }
    }
}
