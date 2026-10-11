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
// the list then scrolls). Cards slide in from the right, a dismissed one
// slides out and its neighbours close the gap, clear-all sweeps them out
// one after another; empty, the shared quiet line (StageEmpty).
Group {
    id: root

    readonly property var groups: Notifications.groupsByAppName
    readonly property int count: Notifications.appNameList.length
    readonly property real rowH: Space.controlM + Space.s
    readonly property real rowGap: Space.xs
    readonly property real listH: Math.max(1, root.count) * (root.rowH + root.rowGap) - root.rowGap
    readonly property real wantedHeight: root.chrome + root.listH
    readonly property real minimumHeight: root.chrome + root.rowH

    fill: true
    implicitHeight: root.wantedHeight
    label: I18n.t("dashboard.stage.notifications")
    actionText: root.count > 1 ? I18n.t("dashboard.stage.clear_all") : ""
    onActionTriggered: Notifications.discardAllNotifications()
    // Cleared: the cards sweep out before the empty line shows.
    onCountChanged: if (root.count === 0 && Motion.glide.duration > 0)
        sweep.restart()

    Timer {
        id: sweep
        interval: Motion.glide.duration + Motion.delay * 2
    }

    ListView {
        id: list
        objectName: "notifList"
        width: parent.width
        height: Math.max(root.rowH, root.bodyHeight)
        visible: root.count > 0 || sweep.running
        clip: true
        spacing: root.rowGap
        boundsBehavior: Flickable.StopAtBounds
        model: KeyedListModel {
            keys: Notifications.appNameList
        }

        delegate: StageNotificationCard {
            id: card
            required property string key
            objectName: "notifRow"
            width: ListView.view.width
            height: root.rowH
            live: HomeModel.groupRow(root.groups[card.key] ?? null)
            onDismissed: Notifications.discardNotifications(card.row.ids)
        }

        add: Transition {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.glide.duration
            }
            NumberAnimation {
                property: "x"
                from: Space.xl
                to: 0
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        // Cleared together: one after another (index x the stagger step).
        remove: Transition {
            enabled: Motion.glide.duration > 0
            SequentialAnimation {
                PauseAnimation {
                    duration: Math.max(0, Math.min(4, ViewTransition.index)) * Motion.delay
                }
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Motion.glide.duration
                    }
                    NumberAnimation {
                        property: "x"
                        to: list.width
                        duration: Motion.glide.duration
                        easing.type: Motion.exit.easing
                    }
                }
            }
        }
        // The gap closes once the leaving card is mostly out.
        displaced: Transition {
            enabled: Motion.glide.duration > 0
            SequentialAnimation {
                PauseAnimation {
                    duration: Motion.micro.duration
                }
                NumberAnimation {
                    properties: "x,y"
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }
    }

    StageEmpty {
        objectName: "emptyState"
        height: Math.max(root.rowH, root.bodyHeight)
        visible: root.count === 0 && !sweep.running
        icon: Icons.bellZ
        text: I18n.t("dashboard.home.no_notifications")
    }
}
