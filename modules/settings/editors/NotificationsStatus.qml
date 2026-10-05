import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.modules.settings

// Where notifications show right now (presentation "auto" resolved against
// the active preset's bar style), whether Do Not Disturb is in effect, and
// a test notification to see the result.
Item {
    id: root

    property var entry
    readonly property string presentation: Notifications.presentation ?? "notch"
    readonly property string position: Notifications.cornerPosition ?? "top-right"
    readonly property bool dnd: !!Notifications.silent

    implicitHeight: line.implicitHeight

    StatusLine {
        id: line

        width: parent.width
        icon: root.dnd ? "bellZ" : (root.presentation === "notch" ? "dotsThree" : "frameCorners")
        tone: root.dnd ? "warn" : "ok"
        title: root.presentation === "notch" ? I18n.t("prefs.notif.status.notch") : I18n.t("prefs.notif.status.corner", I18n.t("prefs.notif.position." + root.position))
        detail: root.dnd ? I18n.t("prefs.notif.status.dnd") : I18n.t("prefs.notif.status.live")

        PillButton {
            objectName: "testNotification"
            kind: "ghost"
            icon: "bellRinging"
            text: I18n.t("prefs.notif.test")
            onClicked: Notifications.notifyInternal({
                "summary": I18n.t("prefs.notif.test.summary"),
                "body": I18n.t("prefs.notif.test.body"),
                "appName": Brand.displayName,
                "appIcon": "preferences-system-notifications",
                "urgency": "normal"
            })
        }
    }
}
