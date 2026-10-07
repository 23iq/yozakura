import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.notifications
import qs.modules.components.kit
import qs.config
import "../notifications/notification_utils.js" as NotificationUtils
import "NotificationBody.js" as NotificationBody

// notifications.notchStyle "compact": one quiet line in the notch (small
// app icon, "summary · body" in the secondary role, the time). Hovering the
// notch unfolds it: the summary on its own line, the body on up to three,
// then the dismiss and action buttons. The row keeps its height while
// collapsed so a new notification never makes the notch jump.
Item {
    id: compact

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0

    readonly property bool critical: !!compact.notification && compact.notification.urgency == NotificationUrgency.Critical
    readonly property int iconSize: compact.hovered ? Space.controlS : Space.l + Space.xs
    // Motion tokens (var: their sub-objects are untyped for qmllint)
    readonly property var morph: Motion.morph

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: compact.hovered ? Space.s : 0

        RowLayout {
            width: parent.width
            spacing: Space.m

            NotificationAppIcon {
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
                Layout.alignment: compact.hovered ? Qt.AlignTop : Qt.AlignVCenter
                size: compact.iconSize
                radius: Space.smallRadius
                appName: compact.notification ? compact.notification.appName : ""
                appIcon: compact.notification ? (compact.notification.cachedAppIcon || compact.notification.appIcon) : ""
                image: compact.notification ? (compact.notification.cachedImage || compact.notification.image) : ""
                summary: compact.notification ? compact.notification.summary : ""
                urgency: compact.notification ? compact.notification.urgency : NotificationUrgency.Normal

                Behavior on size {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: compact.morph.duration
                        easing.type: compact.morph.easing
                    }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                // Collapsed: everything on one elided line
                KitText {
                    width: parent.width
                    visible: !compact.hovered
                    role: "secondary"
                    color: compact.critical ? Colors.criticalText : Type.secondary
                    text: compact.notification ? NotificationBody.oneLine(compact.notification.summary, compact.notification.body, compact.notification.appName) : ""
                }
                // Hovered: summary, then the body
                KitText {
                    width: parent.width
                    visible: compact.hovered
                    role: "body"
                    font.weight: Look.activeLabelWeight
                    color: compact.critical ? Colors.criticalText : Type.text
                    text: compact.notification ? compact.notification.summary : ""
                }
                KitText {
                    width: parent.width
                    visible: compact.hovered && text !== ""
                    role: "secondary"
                    color: compact.critical ? Colors.criticalText : Type.secondary
                    text: compact.notification ? NotificationBody.clean(compact.notification.body, compact.notification.appName) : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                }
            }

            KitText {
                Layout.alignment: compact.hovered ? Qt.AlignTop : Qt.AlignVCenter
                role: "caption"
                tabular: true
                text: compact.notification && compact.timestampUpdateCounter >= 0 ? NotificationUtils.getFriendlyNotifTimeString(compact.notification.time) : ""
            }

            NotchNotificationDismiss {
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignTop
                notification: compact.notification
                hovered: compact.hovered
            }
        }

        NotchNotificationActions {
            width: parent.width
            notification: compact.notification
            hovered: compact.hovered
        }
    }
}
