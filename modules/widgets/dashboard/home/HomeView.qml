import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.widgets.dashboard.widgets

// Composed dashboard home (layout.dashboard.home = "composed"): one calm
// surface, no boxes of its own. Left: clock and weather, now playing, quick
// toggles, volume and brightness. A hairline. Right: the shell's month
// calendar and the notifications. Sizes come from Metrics (density aware).
Item {
    id: root

    readonly property int gap: Metrics.padding * 1.5
    readonly property int leftW: Metrics.sheetW
    readonly property int rightW: Metrics.launcherLeftPanelW

    implicitWidth: root.leftW + root.rightW + root.gap * 2 + Metrics.padding * 2 + 2
    implicitHeight: Math.max(Metrics.dashH, left.implicitHeight + Metrics.padding * 2)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.padding
        spacing: root.gap

        ColumnLayout {
            id: left
            Layout.preferredWidth: root.leftW
            Layout.fillHeight: true
            spacing: Metrics.padding

            HomeHeader {
                Layout.fillWidth: true
            }

            HomePlayer {
                Layout.fillWidth: true
            }

            HomeToggles {
                objectName: "toggles"
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }

            HomeLevels {
                Layout.fillWidth: true
            }
        }

        Separator {
            vert: true
        }

        ColumnLayout {
            Layout.preferredWidth: root.rightW
            Layout.fillHeight: true
            spacing: Metrics.spacing

            CalendarWidget {
                objectName: "calendar"
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.rowHeight * 5.5
            }

            HomeNotifications {
                objectName: "notifications"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
