pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// Notifications on the stage home: one card per app (StageNotificationCard:
// app icon tile, bold summary, quiet body, the count; hover offers clear,
// a swipe sideways dismisses), "Notifications" as the label with clear-all
// as its action. As tall as its cards (`wantedHeight`; the host caps it and
// the list then scrolls); empty, one quiet line.
Group {
    id: root

    readonly property var groups: Notifications.groupsByAppName
    readonly property int count: Notifications.appNameList.length
    readonly property real rowH: Space.controlL - Space.xs
    readonly property real rowGap: Space.xs
    readonly property real listH: Math.max(1, root.count) * (root.rowH + root.rowGap) - root.rowGap
    readonly property real wantedHeight: root.chrome + root.listH
    readonly property real minimumHeight: root.chrome + root.rowH

    fill: true
    implicitHeight: root.wantedHeight
    label: I18n.t("dashboard.stage.notifications")
    actionText: root.count > 1 ? I18n.t("dashboard.stage.clear_all") : ""
    onActionTriggered: Notifications.discardAllNotifications()

    ListView {
        objectName: "notifList"
        width: parent.width
        height: Math.max(root.rowH, root.bodyHeight)
        visible: root.count > 0
        clip: true
        spacing: root.rowGap
        boundsBehavior: Flickable.StopAtBounds
        model: Notifications.appNameList

        delegate: StageNotificationCard {
            required property string modelData
            objectName: "notifRow"
            width: ListView.view.width
            height: root.rowH
            row: HomeModel.groupRow(root.groups[modelData] ?? null)
            onDismissed: Notifications.discardNotifications(row.ids)
        }
    }

    // Empty: one quiet line where the cards would be.
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
