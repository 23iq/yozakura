import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.notifications
import qs.modules.components.kit
import "../notifications/notification_utils.js" as NotificationUtils
import "../notifications/ToastModel.js" as ToastModel
import "NotificationBody.js" as NotificationBody

// notifications.notchStyle "compact": one quiet line in the island: the
// app art, the summary, the body run on after it, the time (with "2/3"
// while there are more popups). Hovering unfolds it below that line, which keeps its
// place: the run-on body gives way to the app name, the time to the dismiss
// button, and the body (up to four lines) and the actions (the first one
// primary) open under the text. Click activates.
Item {
    id: compact

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0
    // Place among the popups ("2/3", scroll to move), "" when alone
    property string position: ""

    readonly property bool critical: compact.notification ? ToastModel.isCritical(compact.notification.urgency) : false
    readonly property var art: ToastModel.artOf(compact.notification, name => Quickshell.iconPath(name, true))
    readonly property var actions: ToastModel.actionsOf(compact.notification)
    readonly property string body: compact.notification ? NotificationBody.clean(compact.notification.body, compact.notification.appName) : ""
    readonly property int artSize: Type.iconSize("title")
    readonly property real textX: compact.artSize + Space.m
    readonly property bool unfolds: compact.body !== "" || compact.actions.length > 0

    implicitHeight: line.height + (compact.hovered && compact.unfolds ? Space.s + details.implicitHeight : 0)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (compact.notification)
                Notifications.activateNotification(compact.notification.id);
        }
    }

    // The line: art, summary, run-on body (app name while hovered), time
    // (dismiss while hovered)
    Item {
        id: line
        objectName: "compactLine"
        width: parent.width
        height: Math.max(compact.artSize, summary.implicitHeight)

        Art {
            objectName: "compactArt"
            width: compact.artSize
            height: compact.artSize
            anchors.verticalCenter: parent.verticalCenter
            source: compact.art.source
            radius: compact.art.round ? width / 2 : Space.clampRadius(Space.smallRadius, width)
            icon: compact.critical ? Icons.alert : Icons.bell
            placeholderText: ToastModel.initialOf(compact.notification)
        }

        KitText {
            id: summary
            x: compact.textX
            anchors.verticalCenter: parent.verticalCenter
            // Resting: room for the run-on body; hovered: for the app name
            readonly property real room: Math.max(0, trailing.x - Space.m - x)
            width: Math.min(implicitWidth, compact.hovered ? summary.room - Math.min(appMetrics.advanceWidth + Space.s, summary.room * 0.4) : runOn.text !== "" ? summary.room * 0.6 : summary.room)
            role: "body"
            font.weight: Look.activeLabelWeight
            text: compact.notification ? (compact.notification.summary || compact.notification.appName || "") : ""
        }
        KitText {
            id: runOn
            anchors.left: summary.right
            anchors.leftMargin: Space.s
            anchors.right: trailing.left
            anchors.rightMargin: Space.m
            anchors.baseline: summary.baseline
            role: "secondary"
            opacity: compact.hovered ? 0 : 1
            visible: opacity > 0
            text: compact.notification ? NotificationBody.oneLine("", compact.notification.body, compact.notification.appName) : ""
            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
        KitText {
            id: appName
            anchors.left: summary.right
            anchors.leftMargin: Space.s
            anchors.right: trailing.left
            anchors.rightMargin: Space.m
            anchors.baseline: summary.baseline
            role: "caption"
            color: Type.muted
            opacity: compact.hovered ? 1 : 0
            visible: opacity > 0
            text: compact.notification ? (compact.notification.appName || "") : ""
            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
        // The app name's natural width (its own width follows the anchors)
        TextMetrics {
            id: appMetrics
            font: appName.font
            text: appName.text
        }

        // The time and the dismiss button share one slot at the end
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(time.implicitWidth, dismiss.width)
            height: parent.height

            KitText {
                id: time
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                tabular: true
                color: compact.critical ? Colors.error : Type.muted
                opacity: compact.hovered ? 0 : 1
                text: compact.notification && compact.timestampUpdateCounter >= 0 ? ToastModel.caption("", NotificationUtils.getFriendlyNotifTimeString(compact.notification.time, I18n.t), 0, compact.position) : ""
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
            }
            IconButton {
                id: dismiss
                objectName: "notificationDismiss"
                anchors.right: parent.right
                anchors.rightMargin: -Space.xs
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                icon: Icons.cancel
                Accessible.name: I18n.t("common.close")
                opacity: compact.hovered ? 1 : 0
                enabled: compact.hovered
                onClicked: {
                    if (compact.notification)
                        Notifications.discardNotification(compact.notification.id);
                }
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
            }
        }
    }

    // Unfolded: the whole body and the actions, under the text
    Column {
        id: details
        objectName: "compactDetails"
        x: compact.textX
        y: line.height + Space.s
        width: parent.width - compact.textX
        spacing: Space.s
        visible: compact.hovered && compact.unfolds

        KitText {
            width: parent.width
            visible: text !== ""
            role: "secondary"
            text: compact.body
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
        ToastActions {
            objectName: "toastActions"
            width: parent.width
            visible: compact.actions.length > 0
            actions: compact.actions
            primaryFirst: true
            onInvoked: identifier => {
                if (compact.notification)
                    Notifications.attemptInvokeAction(compact.notification.id, identifier);
            }
        }
    }
}
