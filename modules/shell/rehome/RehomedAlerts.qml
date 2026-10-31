import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.islandchips

// The island's muted microphone and bell in a corner pill (CornerPills):
// the bar chips' contents side by side. Mic: click toggles the mute; bell:
// click opens the history (NotificationsPopup), right click toggles
// do-not-disturb. `popupBar` places the popup ({barPosition, screen}).
Row {
    id: root

    property var popupBar: null
    property real size: Space.chip
    property bool showMic: false
    property bool showBell: false
    // The mic notice is for this pill's screen
    property bool micNotice: false
    readonly property bool popupOpen: popup.isOpen

    spacing: Space.s

    MicChipContent {
        id: mic
        visible: root.showMic
        moduleSize: root.size
        glyphSize: Type.iconSize("body")
        textSize: Type.size("secondary")
        textWeight: Type.weight("secondary")
        notice: root.micNotice
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: Audio.toggleMicMute()
        }
    }
    NotificationsChipContent {
        id: bell
        visible: root.showBell
        moduleSize: root.size
        glyphSize: Type.iconSize("body")
        textSize: Type.size("secondary")
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (point, button) => button === Qt.RightButton ? Notifications.toggleDnd() : popup.toggle()
        }
    }

    NotificationsPopup {
        id: popup
        anchorItem: bell
        bar: root.popupBar
    }
}
