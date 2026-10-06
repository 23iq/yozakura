import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.notifications
import qs.config
import "../notifications/notification_utils.js" as NotificationUtils
import "NotificationBody.js" as NotificationBody

// notifications.notchStyle "compact": one quiet line in the notch (small
// app icon, "summary · body", time). Hovering the notch unfolds it: the
// summary on its own line, the body on up to three, then the dismiss and
// action buttons. The row keeps its height while collapsed so a new
// notification never makes the notch jump.
Item {
    id: compact

    property var notification
    property bool hovered: false
    property int timestampUpdateCounter: 0

    readonly property bool critical: !!compact.notification && compact.notification.urgency == NotificationUrgency.Critical
    readonly property color textColor: compact.critical ? Colors.criticalText : Colors.overBackground
    readonly property int iconSize: compact.hovered ? Metrics.iconSize + Metrics.spacing : Metrics.iconSize
    // Motion tokens (var: their sub-objects are untyped for qmllint)
    readonly property var morph: Motion.morph

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: compact.hovered ? Metrics.spacing : 0

        RowLayout {
            width: parent.width
            spacing: Metrics.spacing

            NotificationAppIcon {
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
                Layout.alignment: compact.hovered ? Qt.AlignTop : Qt.AlignVCenter
                size: compact.iconSize
                radius: Styling.radius(2)
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
                spacing: 2

                // Collapsed: everything on one elided line
                Text {
                    width: parent.width
                    visible: !compact.hovered
                    text: compact.notification ? NotificationBody.oneLine(compact.notification.summary, compact.notification.body, compact.notification.appName) : ""
                    textFormat: Text.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: compact.textColor
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
                // Hovered: summary, then the body
                Text {
                    width: parent.width
                    visible: compact.hovered
                    text: compact.notification ? compact.notification.summary : ""
                    textFormat: Text.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    color: compact.critical ? Colors.criticalText : Styling.srItem("overprimary")
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    width: parent.width
                    visible: compact.hovered && text !== ""
                    text: compact.notification ? NotificationBody.clean(compact.notification.body, compact.notification.appName) : ""
                    textFormat: Text.StyledText
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: compact.textColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.alignment: compact.hovered ? Qt.AlignTop : Qt.AlignVCenter
                text: compact.notification ? (compact.timestampUpdateCounter >= 0 ? NotificationUtils.getFriendlyNotifTimeString(compact.notification.time) : "") : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.features: {
                    "tnum": 1
                }
                color: Colors.outline
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
