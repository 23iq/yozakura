pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.thumbs
import "../controls/Strip.js" as Strip
import qs.modules.settings.store
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../controls/PictureGrid.js" as PictureGrid
import qs.modules.components.kit

// The bar's shape (bar.layout.style): full, floating, islands, pills,
// dock-like or none, each pictured as a close crop of your bar's edge over
// your wallpaper (thumbs/BarShapeThumb.qml).
Item {
    id: root

    property var entry
    readonly property string current: Config.bar.layout && Config.bar.layout.style ? Config.bar.layout.style : "classic"
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures, scrolling sideways with an edge
    // fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: PanelStyles.barStyles().length
    // landscape pictures (16:10) with the title under them: as tall as the
    // card allows, three whole ones and a peek when they do not all fit
    readonly property real stripWidth: Strip.landscapeWidth(root.width, root.fillHeight, root.stripCount, Space.m, Space.s + Type.size("secondary") * 1.4, Space.px(96))
    readonly property int columns: root.strip ? root.stripCount : PictureGrid.columns(width, grid.columnSpacing, root.stripCount, Space.px(124))
    readonly property real cardWidth: PictureGrid.cardWidth(grid.width, grid.columnSpacing, root.columns, Space.px(150))

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    readonly property int currentIndex: PanelStyles.BAR_STYLES.indexOf(root.current)
    // the chosen picture scrolled into view
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
            rowSpacing: Space.l
            columnSpacing: Space.m

            Repeater {
                model: PanelStyles.barStyles()

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    objectName: "card:" + modelData.id
                    width: root.strip ? root.stripWidth : root.cardWidth
                    previewHeight: root.strip ? Math.round(width * 10 / 16) : Math.round(width * 0.5)
                    selected: root.current === modelData.id
                    title: I18n.t(modelData.label)
                    onClicked: SettingsStore.set("bar.layout.style", modelData.id)

                    BarShapeThumb {
                        anchors.fill: parent
                        style: card.modelData.id
                        edge: Config.bar.position || "top"
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
