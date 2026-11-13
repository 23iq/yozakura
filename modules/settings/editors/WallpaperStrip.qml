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
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string current: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property var paths: root.manager ? (root.manager.wallpaperPaths || []) : []
    readonly property real thumbH: root.fillHeight > 0 ? root.fillHeight : Space.px(72)
    readonly property real thumbW: Math.round(root.thumbH * 16 / 9)

    implicitHeight: root.thumbH

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
        height: root.thumbH + Space.xs * 2
        clip: true

        ListView {
            id: list
            objectName: "wallpaperStrip"
            x: Space.xs
            y: Space.xs
            width: root.width
            height: root.thumbH
            orientation: ListView.Horizontal
            spacing: Space.s
            model: root.paths
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: root.thumbW * 4
            currentIndex: root.paths.indexOf(root.current)
            highlightFollowsCurrentItem: false
            // the one on screen in view
            onCurrentIndexChanged: if (currentIndex >= 0)
                Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Contain))
            Component.onCompleted: if (currentIndex >= 0)
                Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Contain))

            delegate: ChoiceCard {
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

            footer: Item {
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
