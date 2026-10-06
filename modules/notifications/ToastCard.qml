pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ToastModel.js" as ToastModel
import "notification_utils.js" as NotificationUtils

// The content of one corner toast, built from the kit: the sender's art
// (the image round, else the app icon), the summary (body, semibold), the
// body (secondary, two lines), a caption with the app, the group count and
// the time, a ProgressLine for a progress hint and the actions as quiet
// Chips. The dismiss button shows while hovered. No box: CornerToast puts
// it on a Surface.
Item {
    id: root

    property var notification: null
    property int extra: 0
    property bool hovered: false
    readonly property bool critical: root.notification ? ToastModel.isCritical(root.notification.urgency) : false
    readonly property var art: ToastModel.artOf(root.notification)
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
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Space.controlM
            Layout.preferredHeight: Space.controlM
            source: root.art.source
            radius: root.art.round ? width / 2 : Space.clampRadius(Space.controlRadius, width)
            icon: root.critical ? Icons.alert : Icons.bell
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Space.xs

            KitText {
                Layout.fillWidth: true
                role: "body"
                font.weight: Font.DemiBold
                text: root.notification ? (root.notification.summary || root.notification.appName || "") : ""
            }

            KitText {
                Layout.fillWidth: true
                visible: text !== ""
                role: "secondary"
                text: root.body
                wrapMode: Text.Wrap
                maximumLineCount: 2
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
                text: root.notification ? ToastModel.caption(root.notification.appName, NotificationUtils.getFriendlyNotifTimeString(root.notification.time, I18n.t), root.extra) : ""
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Space.xs
                visible: root.actions.length > 0
                spacing: Space.s

                Repeater {
                    model: root.actions

                    Chip {
                        required property var modelData
                        text: modelData.text
                        onClicked: root.actionInvoked(modelData.identifier)
                    }
                }
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: -Space.s
            Layout.rightMargin: -Space.s
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
