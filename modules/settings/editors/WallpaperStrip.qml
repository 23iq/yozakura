pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.controls
import "../controls/PictureGrid.js" as PictureGrid

// The wallpaper library: real thumbnails of every folder, the one on screen
// ringed and scrolled into view; a click sets it live. In its card (no
// `fillHeight`, the Library card that leads the Wallpapers tab) a grid of
// up to four rows (it scrolls past them), then a line with the Folders chip
// and where the colours come from (a link to Theme & colours: they are
// shown and changed there, not here). Given a height (`fillHeight`): a film
// strip ending in the Folders chip, or a grid of whole rows when taller
// than two rows of thumbnails.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string current: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property var paths: root.manager ? (root.manager.wallpaperPaths || []) : []
    readonly property string preset: String(SettingsStore.get("wallpaper.activeColorPreset") || "")
    readonly property real rowH: Space.px(72)
    // in a card: a grid of its own height (as many rows as the library, four at most)
    readonly property bool inCard: root.fillHeight <= 0
    // as many columns as fit, or a neighbour that ends the grid on an even
    // or more than half full row (never 3 + 3 + 3 + 1: PictureGrid)
    readonly property int cardCols: PictureGrid.libraryColumns(root.paths.length, Math.max(2, Math.floor((root.width + Space.s) / (Space.px(128) + Space.s))), 4)
    readonly property int cardRows: Math.max(1, Math.min(4, Math.ceil(root.paths.length / root.cardCols)))
    readonly property real cardThumbH: Math.round(((root.width + Space.s) / root.cardCols - Space.s) * 9 / 16)
    readonly property real gridH: root.inCard ? root.cardRows * (root.cardThumbH + Space.s) - Space.s : root.fillHeight
    readonly property bool grid: root.inCard || root.fillHeight >= root.rowH * 2 + Space.s
    // the grid: whole rows in the height, as many 16:9 cells as fit a row
    readonly property int rows: root.inCard ? root.cardRows : root.grid ? Math.max(2, Math.floor((root.fillHeight + Space.s) / (root.rowH + Space.s))) : 1
    readonly property real thumbH: root.inCard ? root.cardThumbH : root.grid ? Math.floor((root.fillHeight - Space.s * (root.rows - 1)) / root.rows) : root.fillHeight > 0 ? root.fillHeight : root.rowH
    readonly property int perRow: root.inCard ? root.cardCols : Math.max(1, Math.floor((root.width + Space.s) / (root.thumbH * 16 / 9 + Space.s)))
    readonly property real thumbW: root.grid ? Math.floor((root.width + Space.s) / root.perRow) - Space.s : Math.round(root.thumbH * 16 / 9)

    implicitHeight: root.inCard ? root.gridH + Space.m + cardFoot.height : root.grid ? root.fillHeight : root.thumbH

    function source(path) {
        if (!path || !root.manager)
            return "";
        const shown = root.manager.getDisplaySource ? root.manager.getDisplaySource(path) : path;
        return String(shown).startsWith("/") ? "file://" + shown : String(shown);
    }
    function fileName(path) {
        const s = String(path || "");
        return s.substring(s.lastIndexOf("/") + 1);
    }
    function pick(path) {
        if (root.manager && path !== root.current)
            root.manager.setWallpaper(path);
    }

    // clips the strip a ring's width outside it: the chosen picture's ring
    // and a hovered one's lift stay whole at the ends
    Item {
        x: -Space.xs
        y: -Space.xs
        width: root.width + Space.xs * 2
        height: (root.grid ? root.gridH : root.thumbH) + Space.xs * 2
        clip: true

        ListView {
            id: list
            objectName: "wallpaperStrip"
            visible: !root.grid
            x: Space.xs
            y: Space.xs
            width: root.width
            height: root.thumbH
            orientation: ListView.Horizontal
            spacing: Space.s
            model: root.grid ? [] : root.paths
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: Math.max(0, root.thumbW * 4)
            currentIndex: root.paths.indexOf(root.current)
            highlightFollowsCurrentItem: false
            // the one on screen in view
            onCurrentIndexChanged: if (currentIndex >= 0)
                Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Contain))
            Component.onCompleted: if (currentIndex >= 0)
                Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Contain))

            delegate: thumb

            footer: root.grid ? null : stripFolders
        }

        Component {
            id: stripFolders
            Item {
                width: folders.width + Space.s
                height: list.height
                Chip {
                    id: folders
                    objectName: "wallpaperFolders"
                    x: Space.s
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.folder
                    text: I18n.t("prefs.wall.section.folders")
                    onClicked: SettingsStore.navigate("wallpapers", "folders", "desktop.wallpaperFolders")
                }
            }
        }

        GridView {
            id: gridView
            objectName: "wallpaperGrid"
            visible: root.grid
            x: Space.xs
            y: Space.xs
            width: root.width + Space.s
            height: root.gridH
            cellWidth: root.thumbW + Space.s
            cellHeight: root.thumbH + Space.s
            model: root.grid ? root.paths : []
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: Math.max(0, root.thumbH * 4)
            currentIndex: root.paths.indexOf(root.current)
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: if (currentIndex >= 0)
                Qt.callLater(() => gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain))
            Component.onCompleted: if (currentIndex >= 0)
                Qt.callLater(() => gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain))

            delegate: thumb

            footer: root.inCard ? null : gridFoldersFooter
        }
    }

    Component {
        id: gridFoldersFooter
        Item {
            width: gridView.width
            height: gridFolders.height + Space.s
            Chip {
                id: gridFolders
                objectName: "wallpaperFolders"
                icon: Icons.folder
                text: I18n.t("prefs.wall.section.folders")
                onClicked: SettingsStore.navigate("wallpapers", "folders", "desktop.wallpaperFolders")
            }
        }
    }

    // In the card, under the grid: the folders, and where the colours come
    // from (the palette's three accents, a link to Theme & colours).
    Flow {
        id: cardFoot
        objectName: "wallpaperCardFoot"
        visible: root.inCard
        y: root.gridH + Space.m
        width: root.width
        height: root.inCard ? implicitHeight : 0
        spacing: Space.m

        Chip {
            objectName: "wallpaperFolders"
            dense: true
            icon: Icons.folder
            text: I18n.t("prefs.wall.section.folders")
            onClicked: SettingsStore.navigate("wallpapers", "folders", "desktop.wallpaperFolders")
        }
        Row {
            height: colourLink.height
            spacing: Space.s
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -Space.xs
                Repeater {
                    model: [Colors.primary, Colors.secondary, Colors.tertiary]
                    delegate: Mark {
                        required property color modelData
                        width: Space.m + Space.xs
                        height: width
                        color: modelData
                        border.width: Space.hairline
                        border.color: Look.cardFill(false)
                    }
                }
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: root.preset ? I18n.t("prefs.wall.colours_preset", root.preset) : I18n.t("prefs.wall.colours_from")
            }
            Chip {
                id: colourLink
                objectName: "wallpaperSchemeLink"
                dense: true
                quiet: true
                trailingIcon: Icons.caretRight
                text: I18n.t("prefs.cat.appearance")
                onClicked: SettingsStore.navigate("appearance", "palette", "wallpaper.matugenScheme")
            }
        }
    }

    Component {
        id: thumb

        ChoiceCard {
            id: card
            required property string modelData
            objectName: "wallpaper:" + root.fileName(card.modelData)
            width: root.thumbW
            previewHeight: root.thumbH
            inset: true
            selected: card.modelData === root.current
            title: card.hovered ? root.fileName(card.modelData) : ""
            onClicked: root.pick(card.modelData)

            Art {
                anchors.fill: parent
                radius: 0
                source: root.source(card.modelData)
            }
            Icon {
                visible: root.manager && root.manager.getFileType && root.manager.getFileType(card.modelData) !== "image"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.xs
                icon: Icons.play
                role: "caption"
                tone: "text"
            }
        }
    }

    KitText {
        visible: root.paths.length === 0
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        role: "secondary"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.t("prefs.wall.empty")
    }
}
