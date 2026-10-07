import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config

// Dismiss button of a notification in the notch (a kit IconButton); grows
// in while the notch is hovered.
Item {
    id: dismiss

    property var notification
    property bool hovered: false

    implicitWidth: dismiss.hovered ? Space.controlS : 0
    implicitHeight: dismiss.hovered ? Space.controlS : 0
    clip: true
    z: 200

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    IconButton {
        objectName: "notificationDismiss"
        anchors.right: parent.right
        size: "s"
        visible: dismiss.hovered
        icon: Icons.cancel
        Accessible.name: I18n.t("common.close")
        onClicked: {
            if (dismiss.notification)
                Notifications.discardNotification(dismiss.notification.id);
        }
    }
}
