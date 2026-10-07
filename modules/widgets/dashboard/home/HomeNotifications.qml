pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Notifications on the composed dashboard: one line per app (its icon, the
// latest "summary · body", how many), no caption. Hovering a row offers to
// clear that app; with several apps a quiet clear-all closes the list.
// As tall as its rows (`wantedHeight`; the host caps it and the list then
// scrolls), so the calendar above takes the rest; empty, one quiet line.
Group {
    id: root

    readonly property var groups: Notifications.groupsByAppName
    readonly property int count: Notifications.appNameList.length
    readonly property real rowH: Space.controlS
    readonly property real rowGap: Space.xs / 2
    readonly property real footerH: root.count > 1 ? Space.controlS : 0
    readonly property real listH: Math.max(1, root.count) * (root.rowH + root.rowGap) - root.rowGap
    readonly property real wantedHeight: root.chrome + root.listH + (root.footerH > 0 ? root.footerH + Space.m : 0)
    readonly property real minimumHeight: root.chrome + root.rowH

    fill: true

    ListView {
        id: list
        objectName: "notifList"
        width: parent.width
        height: Math.max(root.rowH, root.bodyHeight - (root.footerH > 0 ? root.footerH + Space.m : 0))
        visible: root.count > 0
        clip: true
        spacing: root.rowGap
        boundsBehavior: Flickable.StopAtBounds
        model: Notifications.appNameList

        delegate: ListRow {
            id: entry

            required property string modelData
            readonly property var row: HomeModel.groupRow(root.groups[entry.modelData] ?? null)

            objectName: "notifRow"
            width: ListView.view.width
            height: root.rowH
            title: entry.row.text
            leading: Component {
                Avatar {
                    width: Space.xl
                    height: width
                    name: entry.row.app
                    source: HomeModel.avatarSource(entry.row)
                }
            }
            trailing: Component {
                Item {
                    implicitWidth: Space.controlS - Space.s
                    implicitHeight: implicitWidth

                    KitText {
                        anchors.centerIn: parent
                        visible: !entry.hovered && entry.row.count > 1
                        role: "caption"
                        tabular: true
                        text: entry.row.count
                    }

                    IconButton {
                        objectName: "clearGroup"
                        anchors.fill: parent
                        visible: entry.hovered
                        icon: Icons.cancel
                        onClicked: Notifications.discardNotifications(entry.row.ids)
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: root.footerH
        visible: root.footerH > 0

        IconButton {
            id: clearAll
            objectName: "clearAll"
            anchors.right: parent.right
            size: "s"
            icon: Icons.broom
            onClicked: Notifications.discardAllNotifications()
        }
    }

    // Empty: one quiet line where the rows would be.
    Row {
        objectName: "emptyState"
        height: root.rowH
        x: Space.s
        spacing: Space.m
        visible: root.count === 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.bellZ
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: Type.muted
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: I18n.t("dashboard.home.no_notifications")
        }
    }
}
