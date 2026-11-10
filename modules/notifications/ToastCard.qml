pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ToastModel.js" as ToastModel
import "notification_utils.js" as NotificationUtils

// The content of one corner toast, built from the kit: the sender's art
// (the image round, else the app icon, else the app initial), the summary (body, semibold), the
// body (secondary, two lines), a caption with the app, the group count and
// the time, a ProgressLine for a progress hint and the actions as quiet
// Chips. The dismiss button shows while hovered. No box: CornerToast puts
// it on a Surface; the notch (NotchNotificationCard) shows it in the island
// with the actions only while hovered (`showActions`), the first one as the
// primary action (`primaryAction`) and `bodyLines` of body.
Item {
    id: root

    property var notification: null
    property int extra: 0
    // Appended to the caption ("2/3": the notch's place in its popups)
    property string position: ""
    property bool hovered: false
    property bool showActions: true
    property bool primaryAction: false
    property int bodyLines: 3
    // How far the dismiss button reaches into the padding around the card
    // (corner toast); 0 where the card fills a clipping view (the notch)
    property real dismissOutset: Space.s
    // Bumped by the host to refresh the relative time ("2m")
    property int tick: 0
    readonly property bool critical: root.notification ? ToastModel.isCritical(root.notification.urgency) : false
    readonly property var art: ToastModel.artOf(root.notification, name => Quickshell.iconPath(name, true))
    readonly property real progress: ToastModel.progressOf(root.notification)
    readonly property var actions: ToastModel.actionsOf(root.notification)
    readonly property string body: root.notification ? NotificationUtils.processNotificationBody(root.notification.body || "", root.notification.appName) : ""

    signal dismissRequested
    signal actionInvoked(string identifier)

    implicitHeight: layout.implicitHeight

    RowLayout {
        id: layout
        width: root.width
        spacing: Space.m

        Art {
            objectName: "toastArt"
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Space.controlM
            Layout.preferredHeight: Space.controlM
            source: root.art.source
            radius: root.art.round ? width / 2 : Space.clampRadius(Space.controlRadius, width)
            icon: root.critical ? Icons.alert : Icons.bell
            placeholderText: ToastModel.initialOf(root.notification)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Space.xs

            KitText {
                Layout.fillWidth: true
                role: "body"
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.notification ? (root.notification.summary || root.notification.appName || "") : ""
            }

            KitText {
                Layout.fillWidth: true
                visible: text !== ""
                role: "secondary"
                text: root.body
                wrapMode: Text.Wrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
            }

            ProgressLine {
                Layout.fillWidth: true
                Layout.topMargin: Space.xs
                visible: root.progress >= 0
                value: root.progress
            }

            KitText {
                Layout.fillWidth: true
                role: "caption"
                color: root.critical ? Colors.error : Type.muted
                text: root.notification && root.tick >= 0 ? ToastModel.caption(root.notification.appName, NotificationUtils.getFriendlyNotifTimeString(root.notification.time, I18n.t), root.extra, root.position) : ""
            }

            ToastActions {
                objectName: "toastActions"
                Layout.fillWidth: true
                Layout.topMargin: Space.xs
                visible: root.showActions && root.actions.length > 0
                actions: root.actions
                primaryFirst: root.primaryAction
                onInvoked: identifier => root.actionInvoked(identifier)
            }
        }

        IconButton {
            objectName: "notificationDismiss"
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: -root.dismissOutset
            Layout.rightMargin: -root.dismissOutset
            size: "s"
            icon: Icons.cancel
            opacity: root.hovered ? 1 : 0
            enabled: root.hovered
            onClicked: root.dismissRequested()

            Behavior on opacity {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration / 2
                }
            }
        }
    }
}
