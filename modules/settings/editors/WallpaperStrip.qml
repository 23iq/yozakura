pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.controls

// The wallpaper library along the stage's foot (category `hero.foot`): a
// film strip of real thumbnails of every folder, the one on screen ringed
// and scrolled into view, many at once; a click sets it live. Ends with a
// "Folders" chip that opens the folder list. Its height is the strip's
// (`fillHeight`); without one (a card elsewhere) it is a few thumbnails tall.
// Taller than two rows of thumbnails (beside the stage), it is a grid that
// scrolls down, its cells stretched to fill the width.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string current: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property var paths: root.manager ? (root.manager.wallpaperPaths || []) : []
    readonly property real rowH: Space.px(72)
    readonly property bool grid: root.fillHeight >= root.rowH * 2 + Space.s
    // the grid: whole rows in the height, as many 16:9 cells as fit a row
    readonly property int rows: root.grid ? Math.max(2, Math.floor((root.fillHeight + Space.s) / (root.rowH + Space.s))) : 1
    readonly property real thumbH: root.grid ? Math.floor((root.fillHeight - Space.s * (root.rows - 1)) / root.rows) : root.fillHeight > 0 ? root.fillHeight : root.rowH
    readonly property int perRow: Math.max(1, Math.floor((root.width + Space.s) / (root.thumbH * 16 / 9 + Space.s)))
    readonly property real thumbW: root.grid ? Math.floor((root.width + Space.s) / root.perRow) - Space.s : Math.round(root.thumbH * 16 / 9)

    implicitHeight: root.grid ? root.fillHeight : root.thumbH

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
        height: (root.grid ? root.fillHeight : root.thumbH) + Space.xs * 2
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
            cacheBuffer: root.thumbW * 4
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
            height: root.fillHeight
            cellWidth: root.thumbW + Space.s
            cellHeight: root.thumbH + Space.s
            model: root.grid ? root.paths : []
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: root.thumbH * 4
            currentIndex: root.paths.indexOf(root.current)
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: if (currentIndex >= 0)
                Qt.callLater(() => gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain))
            Component.onCompleted: if (currentIndex >= 0)
                Qt.callLater(() => gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain))

            delegate: thumb

            footer: Item {
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
