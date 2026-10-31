import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.islandchips

// The idle island's media in the bar: art + title + mini visualizer
// (MediaChipContent). Click opens the media panel (MediaPopup), middle
// click plays/pauses. Shown only while the island does not show the media
// itself (ShellLayout.homeOf, LayoutModel.js). moduleOptions.media:
// showTitle, visualizer.
BarModuleBase {
    id: root

    moduleKey: "media"

    readonly property bool shown: ShellLayout.homeOf("media") === "bar"
    readonly property string screenName: root.bar && root.bar.screen ? root.bar.screen.name : ""
    readonly property var player: MprisController.activePlayer

    visible: root.shown
    contentLength: root.shown ? (root.vertical ? chip.implicitHeight + Space.s * 2 : chip.implicitWidth + (root.flat ? Space.m : Space.l * 1.5)) : 0

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
        active: popup.isOpen
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.MiddleButton) {
                if (root.player && root.player.canTogglePlaying)
                    root.player.togglePlaying();
                return;
            }
            popup.toggle();
        }
    }

    MediaChipContent {
        id: chip
        anchors.centerIn: parent
        player: root.player
        vertical: root.vertical
        moduleSize: root.moduleSize
        glyphSize: root.iconSize
        textSize: root.textSize
        textWeight: root.textWeight
        textFont: root.textFont
        ink: surface.foreground
        showTitle: root.options.showTitle !== false
        visualizer: root.options.visualizer !== false
        shown: root.visible
    }

    StyledToolTip {
        show: hover.hovered && !popup.isOpen
        tooltipText: chip.hasPlayer ? (chip.artist !== "" ? chip.title + " · " + chip.artist : chip.title) : I18n.t("bar.media.empty")
    }

    MediaPopup {
        id: popup
        anchorItem: surface
        bar: root.bar
        screenName: root.screenName
    }
}
