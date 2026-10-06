pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Notifications on the composed dashboard, filling the height it is given:
// "Notifications · N" with Clear, then one compact ListRow per app group
// (avatar, summary, one line; a group of several shows the app and
// "latest · N more"), scrolling when long; a quiet empty state otherwise.
Item {
    id: root

    readonly property int count: Notifications.list.length
    readonly property var groups: Notifications.groupsByAppName
    // Smallest useful height: the group around two rows.
    readonly property real minimumHeight: group.chrome + Space.rowHeight * 2

    implicitWidth: group.implicitWidth
    implicitHeight: root.minimumHeight

    Group {
        id: group
        objectName: "notifGroup"
        width: parent.width
        divider: true
        label: I18n.t("dashboard.home.notifications") + (root.count > 0 ? " · " + root.count : "")
        actionText: root.count > 0 ? I18n.t("common.clear") : ""
        onActionTriggered: Notifications.discardAllNotifications()

        Item {
            width: parent.width
            height: Math.max(Space.rowHeight * 2, root.height - group.chrome)

            ListView {
                id: list
                objectName: "notifList"
                anchors.fill: parent
                clip: true
                spacing: Space.xs
                boundsBehavior: Flickable.StopAtBounds
                model: Notifications.appNameList

                delegate: ListRow {
                    id: entry

                    required property string modelData
                    readonly property var row: HomeModel.groupRow(root.groups[entry.modelData] ?? null, n => I18n.t("dashboard.home.more", n))

                    width: ListView.view.width
                    title: entry.row.title
                    subtitle: entry.row.body
                    leading: Component {
                        Avatar {
                            name: entry.row.app
                            source: HomeModel.avatarSource(entry.row)
                        }
                    }
                }
            }

            Column {
                objectName: "emptyState"
                anchors.centerIn: parent
                spacing: Space.s
                visible: list.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.bellZ
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("title")
                    color: Type.muted
                }

                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "caption"
                    text: I18n.t("dashboard.home.no_notifications")
                }
            }
        }
    }
}
