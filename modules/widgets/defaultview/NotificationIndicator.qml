import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config

Item {
    id: root
    implicitWidth: 24
    implicitHeight: 24

    property int previousNotifCount: 0
    property bool hovered: false

    Item {
        id: shakeContainer
        anchors.centerIn: parent
        width: 24
        height: 24

        SequentialAnimation {
            id: shakeAnimation

            NumberAnimation {
                target: shakeContainer
                property: "rotation"
                to: -15
                duration: Motion.emphasis.duration
                easing.type: Motion.emphasis.easing
            }
            NumberAnimation {
                target: shakeContainer
                property: "rotation"
                to: 15
                duration: Motion.emphasis.duration
                easing.type: Motion.emphasis.easing
            }
            NumberAnimation {
                target: shakeContainer
                property: "rotation"
                to: -10
                duration: Motion.emphasis.duration
                easing.type: Motion.emphasis.easing
            }
            NumberAnimation {
                target: shakeContainer
                property: "rotation"
                to: 10
                duration: Motion.emphasis.duration
                easing.type: Motion.emphasis.easing
            }
            NumberAnimation {
                target: shakeContainer
                property: "rotation"
                to: 0
                duration: Motion.emphasis.duration
                easing.type: Motion.emphasis.easing
            }
        }

        Text {
            id: iconText
            anchors.centerIn: parent
            // Focus mode (system.focus.hideBadges) hides the unread state
            readonly property bool unread: Notifications.list.length > 0 && !FocusMode.hideBadges
            text: Notifications.silent ? Icons.bellZ : (iconText.unread ? Icons.bellRinging : Icons.bell)
            textFormat: Text.RichText
            font.family: Icons.font
            font.pixelSize: 18
            color: root.hovered ? Styling.srItem("overprimary") : (iconText.unread ? Colors.error : Colors.overBackground)

            HoverHandler {
                onHoveredChanged: root.hovered = hovered
            }

            TapHandler {
                onTapped: Notifications.toggleDnd()
            }
        }
    }

    Connections {
        target: Notifications
        function onPopupListChanged() {
            if (Notifications.popupList.length > previousNotifCount) {
                shakeAnimation.restart();
            }
            previousNotifCount = Notifications.popupList.length;
        }
    }

    Component.onCompleted: {
        previousNotifCount = Notifications.popupList.length;
    }
}
