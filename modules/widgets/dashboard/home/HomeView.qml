import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit

// Composed dashboard home (layout.dashboard.home = "composed"): one calm
// surface in two columns, no captions; the hierarchy comes from the layout.
// Left: the clock (hero) with the weather, now playing around its art, a
// row of icon toggles and the levels (volume, microphone, brightness).
// Right: a compact month and the notifications, or the details a toggle or
// level opened (networks, Bluetooth devices, audio devices). The view
// offers its natural size and fills whatever it is given: free height goes
// to the player (its art grows) and to the month (its rows grow), so no
// block leaves an empty gap.
Item {
    id: root

    // Around the column divider; boxed groups sit one group gap apart.
    readonly property int gap: Look.groupBoxed ? Math.round(Look.groupGap / 2) : Space.xl
    readonly property int leftW: Metrics.sheetW
    readonly property int rightW: Metrics.launcherLeftPanelW
    // What the right column shows instead of the month and notifications.
    property string detail: ""

    function openDetail(kind: string) {
        root.detail = root.detail === kind ? "" : kind;
    }

    onVisibleChanged: {
        if (!visible)
            root.detail = "";
    }

    implicitWidth: root.leftW + root.rightW + root.gap * 2 + Space.hairline
    implicitHeight: Math.max(Metrics.dashH, left.implicitHeight, calendar.minimumHeight + Look.groupGap + notifications.minimumHeight)

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        ColumnLayout {
            id: left
            Layout.preferredWidth: root.leftW
            Layout.horizontalStretchFactor: root.leftW
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Look.groupGap

            Group {
                Layout.fillWidth: true

                HomeHeader {
                    objectName: "header"
                    width: parent.width
                }
            }

            HomePlayer {
                id: player
                objectName: "player"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: player.naturalHeight
                Layout.preferredHeight: player.naturalHeight
                divider: true
            }

            Group {
                Layout.fillWidth: true
                divider: true

                HomeToggles {
                    objectName: "toggles"
                    width: parent.width
                    onDetails: kind => root.openDetail(kind)
                }

                HomeLevels {
                    objectName: "levels"
                    width: parent.width
                    detail: root.detail
                    onDetails: kind => root.openDetail(kind)
                }
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
            id: right
            Layout.preferredWidth: root.rightW
            Layout.horizontalStretchFactor: root.rightW
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Look.groupGap

            // The month takes what the notifications leave: no empty block
            // under a short list, and an empty list is one quiet line.
            HomeCalendar {
                id: calendar
                objectName: "calendar"
                visible: root.detail === ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: calendar.minimumHeight
                Layout.preferredHeight: calendar.minimumHeight
            }

            HomeNotifications {
                id: notifications
                objectName: "notifications"
                visible: root.detail === ""
                divider: true
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(notifications.wantedHeight, Math.max(notifications.minimumHeight, right.height - calendar.minimumHeight - right.spacing))
            }

            HomeDetail {
                objectName: "detail"
                visible: root.detail !== ""
                kind: root.detail
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: notifications.minimumHeight
                onDone: root.detail = ""
            }
        }
    }
}
