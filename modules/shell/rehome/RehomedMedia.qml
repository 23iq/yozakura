import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.islandchips

// The island's media in a corner pill (CornerPills): the bar's media chip
// content; click opens the media panel (MediaPopup), middle click
// plays/pauses. `popupBar` places the popup ({barPosition, screen}).
Item {
    id: root

    property var popupBar: null
    property string screenName: ""
    property real size: Space.chip
    property bool shown: true
    readonly property bool popupOpen: popup.isOpen

    implicitWidth: chip.implicitWidth
    implicitHeight: root.size

    MediaChipContent {
        id: chip
        anchors.centerIn: parent
        moduleSize: root.size
        glyphSize: Type.iconSize("body")
        textSize: Type.size("secondary")
        textWeight: Type.weight("secondary")
        ink: Type.text
        showTitle: Config.bar.moduleOptions && Config.bar.moduleOptions.media ? Config.bar.moduleOptions.media.showTitle !== false : true
        visualizer: Config.bar.moduleOptions && Config.bar.moduleOptions.media ? Config.bar.moduleOptions.media.visualizer !== false : true
        shown: root.shown
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onTapped: (point, button) => {
            const p = MprisController.activePlayer;
            if (button === Qt.MiddleButton) {
                if (p && p.canTogglePlaying)
                    p.togglePlaying();
                return;
            }
            popup.toggle();
        }
    }

    MediaPopup {
        id: popup
        anchorItem: root
        bar: root.popupBar
        screenName: root.screenName
    }
}
