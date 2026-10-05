import QtQuick
import qs.modules.services
import ".." as DefaultView

// The media player card (the notch's classic expansion).
NotchPanel {
    id: panel

    implicitHeight: media.implicitHeight

    DefaultView.ExpandedMedia {
        id: media
        width: parent.width
        height: implicitHeight
        player: MprisController.activePlayer
        revealed: panel.revealed
    }
}
