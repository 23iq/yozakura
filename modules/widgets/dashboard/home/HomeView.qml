import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit

// Composed dashboard home (layout.dashboard.home = "composed"): one calm
// surface in two columns split by a Divider, built from the kit's Groups
// (the visual language gives them their look). Left: time, date and
// weather, now playing, quick toggles, levels. Right: the month calendar and
// the notifications, which take the remaining height. The view is as large
// as its content; the dashboard follows it.
Item {
    id: root

    // Around the column divider; boxed groups sit one group gap apart.
    readonly property int gap: Look.groupBoxed ? Math.round(Look.groupGap / 2) : Space.xl
    readonly property int leftW: Metrics.sheetW
    readonly property int rightW: Metrics.launcherLeftPanelW

    implicitWidth: root.leftW + root.rightW + root.gap * 2 + Space.hairline
    implicitHeight: Math.max(Metrics.dashH, left.implicitHeight, calendar.implicitHeight + Look.groupGap + notifications.minimumHeight)

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        // Header, player and toggles from the top; the levels at the bottom.
        Item {
            id: left
            Layout.preferredWidth: root.leftW
            Layout.fillHeight: true
            implicitHeight: top.implicitHeight + Look.groupGap + levels.implicitHeight

            Column {
                id: top
                width: parent.width
                spacing: Look.groupGap

                Group {
                    width: parent.width

                    HomeHeader {
                        objectName: "header"
                        width: parent.width
                    }
                }

                HomePlayer {
                    objectName: "player"
                    width: parent.width
                    divider: true
                }

                Group {
                    width: parent.width
                    divider: true

                    HomeToggles {
                        objectName: "toggles"
                        width: parent.width
                    }
                }
            }

            HomeLevels {
                id: levels
                objectName: "levels"
                anchors.bottom: parent.bottom
                width: parent.width
                divider: true
            }
        }

        // A slot, so the columns keep their place without the divider
        // (hidden where groups are boxes: glass cards, tiles).
        Item {
            implicitWidth: Space.hairline
            Layout.fillHeight: true

            Divider {
                objectName: "columnDivider"
                vertical: true
                anchors.fill: parent
                visible: Look.dividers && !Look.groupBoxed
            }
        }

        ColumnLayout {
            Layout.preferredWidth: root.rightW
            Layout.fillHeight: true
            spacing: Look.groupGap

            HomeCalendar {
                id: calendar
                objectName: "calendar"
                Layout.fillWidth: true
            }

            HomeNotifications {
                id: notifications
                objectName: "notifications"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
