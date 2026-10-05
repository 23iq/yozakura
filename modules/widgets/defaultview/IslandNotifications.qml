import QtQuick
import qs.modules.notch
import qs.config

// Notification toasts inside the resting notch (notifications.presentation
// "notch"). The notch silhouette itself grows to hold them; the content is
// "born" from the notch edge: it unfolds from the header side (scale +
// slide + fade) while the shape expands around it.
Item {
    id: root
    property bool hovered: false
    readonly property bool navigating: notificationView.isNavigating
    readonly property int bottomPadding: Config.notchTheme === "island" ? 20 : 16
    readonly property bool fromBottom: Config.notchPosition === "bottom"
    implicitHeight: notificationView.implicitHeight + 8 + bottomPadding

    // 0 = still inside the notch edge, 1 = fully born
    property real birth: 1
    onVisibleChanged: {
        if (!visible)
            return;
        if (Config.animDuration > 0) {
            root.birth = 0;
            bornAnimation.restart();
        } else {
            root.birth = 1;
        }
    }

    NumberAnimation {
        id: bornAnimation
        target: root
        property: "birth"
        from: 0
        to: 1
        duration: Math.round(Config.animDuration * 1.25)
        easing.type: Easing.OutBack
        easing.overshoot: 1.05
    }

    NotchNotificationView {
        id: notificationView
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: root.bottomPadding
        notchHovered: root.hovered
        opacity: Math.min(1, Math.max(0, root.birth * 1.4 - 0.2))
        transform: [
            Scale {
                origin.x: notificationView.width / 2
                origin.y: root.fromBottom ? notificationView.height : 0
                xScale: 0.9 + 0.1 * root.birth
                yScale: 0.75 + 0.25 * root.birth
            },
            Translate {
                y: (1 - root.birth) * (root.fromBottom ? 14 : -14)
            }
        ]
    }
}
