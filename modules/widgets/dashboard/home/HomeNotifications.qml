pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// Notifications on the composed dashboard, filling the height it is given:
// one line per app (its icon, the latest "summary · body", how many), no
// caption. Hovering a row offers to clear that app; hovering the list
// offers to clear everything (bottom right). A quiet bell when empty.
Group {
    id: root

    readonly property var groups: Notifications.groupsByAppName
    readonly property real rowH: Space.controlS
    readonly property real minimumHeight: root.chrome + root.rowH * 2
    readonly property bool hovered: hover.hovered

    fill: true

    HoverHandler {
        id: hover
    }

    Item {
        width: parent.width
        height: Math.max(root.rowH * 2, root.bodyHeight)

        ListView {
            id: list
            objectName: "notifList"
            anchors.fill: parent
            anchors.bottomMargin: clearAll.visible ? clearAll.height + Space.xs : 0
            clip: true
            spacing: Space.xs / 2
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

                HoverHandler {
                    id: rowHover
                }
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
                            visible: !rowHover.hovered && entry.row.count > 1
                            role: "caption"
                            tabular: true
                            text: entry.row.count
                        }

                        IconButton {
                            objectName: "clearGroup"
                            anchors.centerIn: parent
                            width: parent.width
                            height: width
                            visible: rowHover.hovered
                            icon: Icons.cancel
                            onClicked: Notifications.discardNotifications(entry.row.ids)
                        }
                    }
                }
            }
        }

        IconButton {
            id: clearAll
            objectName: "clearAll"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            size: "s"
            icon: Icons.broom
            visible: list.count > 0
            opacity: root.hovered ? 1 : 0
            onClicked: Notifications.discardAllNotifications()
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
