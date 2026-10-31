pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.widgets.defaultview.panels
import "../../widgets/defaultview/panels/NotchPanels.js" as NotchPanels

// Popup of the media chip: the island's own media panel (MediaPanel from
// NotchPanels.js, in notch.mediaStyle), loaded the way ActivityChipPopup
// loads the activity panels, plus one chip per player to pick the active
// one when several play, and a quiet empty state without a player.
BarPopup {
    id: popup

    property string screenName: ""
    readonly property var entry: NotchPanels.byId("media")
    readonly property bool hasPlayer: !!MprisController.activePlayer
    readonly property var players: MprisController.filteredPlayers || []
    readonly property NotchPanel panel: loader.item as NotchPanel
    readonly property real pad: Look.surfacePadding

    objectName: "mediaPopup"
    popupPadding: 0
    contentWidth: NotchPanels.widthFor("media", Config.notch.expandedMediaWidth)
    contentHeight: Math.max(1, body.implicitHeight)

    Column {
        id: body
        width: parent.width
        topPadding: popup.pad - Space.s
        bottomPadding: popup.players.length > 1 || !popup.hasPlayer ? popup.pad : 0

        Loader {
            id: loader
            width: parent.width
            height: popup.panel ? popup.panel.implicitHeight : 0
            active: popup.hasPlayer && popup.entry !== null
            source: popup.entry ? Qt.resolvedUrl("../../widgets/defaultview/panels/" + popup.entry.url) : ""
            onLoaded: {
                const p = loader.item as NotchPanel;
                if (!p)
                    return;
                p.screenName = Qt.binding(() => popup.screenName);
                p.revealed = Qt.binding(() => popup.isOpen);
                p.closeRequested.connect(popup.close);
            }
        }

        // Several players: pick the one the chip and the panel follow
        Flow {
            objectName: "playerChoice"
            visible: popup.players.length > 1
            x: popup.pad
            width: parent.width - popup.pad * 2
            spacing: Space.xs

            Repeater {
                model: popup.players.length > 1 ? popup.players : []
                Chip {
                    id: choice
                    required property var modelData
                    icon: Icons.musicNotes
                    text: choice.modelData ? (choice.modelData.identity || "") : ""
                    active: choice.modelData === MprisController.activePlayer
                    onClicked: MprisController.setActivePlayer(choice.modelData)
                }
            }
        }

        Column {
            objectName: "mediaEmpty"
            visible: !popup.hasPlayer
            width: parent.width
            topPadding: Space.m
            spacing: Space.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.musicNotes
                font.family: Icons.font
                font.pixelSize: Type.iconSize("title")
                color: Type.muted
            }
            KitText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: I18n.t("bar.media.empty")
            }
        }
    }
}
