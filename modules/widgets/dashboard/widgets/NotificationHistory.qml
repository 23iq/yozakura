pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.notifications
import qs.modules.globals
import qs.modules.components.kit

// Bento widget "notifications": the history as one ListRow per group (app
// icon, summary, one elided line; a group of several shows the app name and
// "latest · N more"). Click runs the notification's default action, the
// trailing x discards the group; the section label's "Clear" (or Ctrl+L on
// the widgets tab) discards everything. A "Silent" chip under the list
// toggles do-not-disturb. Scrolls when long.
HostWidget {
    id: root

    readonly property var groups: Notifications.groupsByAppName
    // A one-column tile keeps the text: a short label, no app icon and no
    // per-row x ("Clear" and Ctrl+L still clear).
    readonly property bool narrow: root.width < Space.rowHeight * 4

    Shortcut {
        sequence: "Ctrl+L"
        enabled: GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 0 && GlobalStates.widgetsTabCurrentIndex === 0
        onActivated: Notifications.discardAllNotifications()
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t(root.narrow ? "bento.label.inbox" : "bento.widget.notifications")
        actionText: list.count > 0 ? I18n.t("common.clear") : ""
        onActionTriggered: Notifications.discardAllNotifications()

        Item {
            width: parent.width
            height: group.bodyHeight - silent.height - Space.m

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
                    readonly property var appGroup: root.groups[entry.modelData] ?? null
                    readonly property var notifs: entry.appGroup ? entry.appGroup.notifications : []
                    readonly property var latest: entry.notifs.length > 0 ? entry.notifs[entry.notifs.length - 1] : null
                    readonly property bool many: entry.notifs.length > 1

                    width: ListView.view.width
                    title: entry.many || !entry.latest?.summary ? (entry.appGroup?.appName ?? "") : entry.latest.summary
                    subtitle: {
                        const l = entry.latest;
                        if (!l)
                            return "";
                        const line = (entry.many ? (l.summary || l.body) : l.body) || "";
                        const flat = line.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
                        return entry.many ? flat + " · " + I18n.t("dashboard.home.more", entry.notifs.length - 1) : flat;
                    }
                    leading: root.narrow ? null : appIcon
                    trailing: root.narrow ? null : dismiss
                    onClicked: {
                        if (entry.latest)
                            Notifications.activateNotification(entry.latest.id);
                    }

                    Component {
                        id: appIcon
                        NotificationAppIcon {
                            width: Space.controlS
                            height: Space.controlS
                            size: Space.controlS
                            radius: Space.round(Space.controlS)
                            appName: entry.latest ? entry.latest.appName : ""
                            appIcon: entry.latest ? (entry.latest.cachedAppIcon || entry.latest.appIcon) : ""
                            image: entry.latest ? (entry.latest.cachedImage || entry.latest.image) : ""
                            summary: entry.latest ? entry.latest.summary : ""
                        }
                    }
                    Component {
                        id: dismiss
                        IconButton {
                            size: "s"
                            icon: Icons.cancel
                            onClicked: Notifications.discardNotifications(entry.notifs.map(n => n.id))
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

        Chip {
            id: silent
            icon: Notifications.silent ? Icons.bellZ : Icons.bell
            text: I18n.t("bento.notifications.silent")
            active: Notifications.silent
            onClicked: Notifications.toggleDnd()
        }
    }
}
