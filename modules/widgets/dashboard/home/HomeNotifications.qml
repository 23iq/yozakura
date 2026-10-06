pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.notifications
import qs.config

// Notification list of the composed dashboard: "NOTIFICATIONS · N" with
// Clear, then one compact row per group (as NotificationHistory.qml groups
// them): icon, bold summary, one elided line. A group of several shows the
// app name and "latest · N more". Scrolls when long.
ColumnLayout {
    id: root

    readonly property int count: Notifications.list.length
    readonly property var groups: Notifications.groupsByAppName

    spacing: 12

    RowLayout {
        Layout.fillWidth: true

        Text {
            objectName: "notifTitle"
            text: I18n.t("dashboard.home.notifications") + (root.count > 0 ? " · " + root.count : "")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.DemiBold
            font.letterSpacing: Styling.fontSize(-3) * 0.14
            font.capitalization: Font.AllUppercase
            color: Colors.outline
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            objectName: "clearButton"
            visible: root.count > 0
            text: I18n.t("common.clear")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: clearArea.containsMouse ? Colors.overBackground : Colors.outline

            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.discardAllNotifications()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            objectName: "notifList"
            anchors.fill: parent
            clip: true
            spacing: 12
            boundsBehavior: Flickable.StopAtBounds
            model: Notifications.appNameList

            delegate: Item {
                id: entry

                required property string modelData
                readonly property var group: root.groups[entry.modelData] ?? null
                readonly property var notifs: entry.group ? entry.group.notifications : []
                readonly property var latest: entry.notifs.length > 0 ? entry.notifs[entry.notifs.length - 1] : null
                readonly property bool many: entry.notifs.length > 1

                width: ListView.view.width
                height: 34

                NotificationAppIcon {
                    id: icon
                    width: 26
                    height: 26
                    size: 26
                    radius: 13
                    appName: entry.latest ? entry.latest.appName : ""
                    appIcon: entry.latest ? (entry.latest.cachedAppIcon || entry.latest.appIcon) : ""
                    image: entry.latest ? (entry.latest.cachedImage || entry.latest.image) : ""
                    summary: entry.latest ? entry.latest.summary : ""
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    spacing: 1

                    Text {
                        width: parent.width
                        text: entry.many || !entry.latest?.summary ? (entry.group?.appName ?? "") : entry.latest.summary
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }

                    Text {
                        width: parent.width
                        text: {
                            const l = entry.latest;
                            if (!l)
                                return "";
                            const line = (entry.many ? (l.summary || l.body) : l.body) || "";
                            const flat = line.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
                            return entry.many ? flat + " · " + I18n.t("dashboard.home.more", entry.notifs.length - 1) : flat;
                        }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                    }
                }
            }
        }

        Column {
            objectName: "emptyState"
            anchors.centerIn: parent
            spacing: 6
            visible: list.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.bellZ
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(6)
                color: Colors.outlineVariant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("dashboard.home.no_notifications")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
            }
        }
    }
}
