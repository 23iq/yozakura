pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.thumbs
import "../controls/Strip.js" as Strip
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../controls/PictureGrid.js" as PictureGrid
import qs.modules.components.kit

// One card per panel style (PanelStyles.js registry), each pictured as a
// close crop of the selected panel's edge in that style (BarShapeThumb).
Item {
    id: root

    property var panel: null
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures, scrolling sideways with an edge
    // fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: PanelStyles.STYLES.filter(s => !s.hidden).length
    // landscape pictures (16:10) with the title under them (Strip.js)
    readonly property real stripWidth: Strip.landscapeWidth(root.width, root.fillHeight, root.stripCount, Space.m, Space.s + Type.size("secondary") * 1.4, Space.px(96))
    readonly property int columns: root.strip ? root.stripCount : PictureGrid.columns(width, Space.m, root.stripCount, Space.px(124))
    readonly property var styles: PanelStyles.STYLES.filter(s => !s.hidden)
    readonly property int currentIndex: root.panel ? root.styles.findIndex(s => s.id === root.panel.style) : -1
    signal picked(string style)

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    // the chosen picture scrolled into view (another bar picked, first show)
    function reveal() {
        if (root.strip)
            stripFlick.contentX = Strip.revealX(stripFlick.contentX, stripFlick.width, stripFlick.contentWidth, root.currentIndex, root.stripWidth, Space.m);
    }
    onCurrentIndexChanged: Qt.callLater(root.reveal)
    onStripWidthChanged: Qt.callLater(root.reveal)
    Component.onCompleted: Qt.callLater(root.reveal)

    Flickable {
        id: stripFlick
        objectName: "pictureStrip"
        width: parent.width
        height: root.strip ? root.fillHeight : grid.height
        contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            width: root.strip ? implicitWidth : stripFlick.width
            // inset: the ring, glow and lift of a picture never clip
            x: root.strip ? Space.m : 0
            y: root.strip ? Math.max(Space.m, (root.fillHeight - grid.height) / 2) : 0
            columns: root.columns
            spacing: Space.m

            Repeater {
                model: root.styles
                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    width: root.strip ? root.stripWidth : PictureGrid.cardWidth(grid.width, grid.spacing, root.columns, Space.px(190))
                    previewHeight: Math.round(width * 10 / 16)
                    selected: root.panel !== null && root.panel.style === modelData.id
                    icon: root.strip ? "" : modelData.icon
                    title: I18n.t(modelData.label)
                    subtitle: root.strip ? "" : I18n.t(modelData.desc)
                    onClicked: root.picked(modelData.id)

                    BarShapeThumb {
                        anchors.fill: parent
                        style: card.modelData.id
                        edge: root.panel ? root.panel.edge : "top"
                    }
                }
            }
        }
    }
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
