pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.services
import qs.modules.components.kit
import ".." as DefaultView

// The media player panel in the style of notch.mediaStyle: "row" (compact
// player row, MediaRow) or "artwork" (large art on a card tinted by the
// artwork, MediaArtwork).
NotchPanel {
    id: panel

    readonly property bool artwork: (Config.notch.mediaStyle ?? "row") === "artwork"
    readonly property var player: MprisController.activePlayer

    implicitHeight: panel.topPadding + group.implicitHeight + panel.padding

    Group {
        id: group
        x: panel.padding
        y: panel.topPadding
        width: parent.width - panel.padding * 2

        Loader {
            width: parent.width
            sourceComponent: panel.artwork ? artworkStyle : rowStyle
        }
    }

    Component {
        id: rowStyle
        DefaultView.MediaRow {
            player: panel.player
            revealed: panel.revealed
        }
    }
    Component {
        id: artworkStyle
        DefaultView.MediaArtwork {
            player: panel.player
            revealed: panel.revealed
        }
    }
}
