pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.controls

// The wallpaper library beside the stage: a film strip of real thumbnails
// of every folder (the one on screen ringed, scrolled into view), a click
// sets it live. Ends with a "Folders" tile that opens the folder list.
// Fills the height of the page hero (the stage beside it).
Item {
    id: root

    property var entry
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string current: root.manager ? (root.manager.currentWallpaper || "") : ""
    readonly property var paths: root.manager ? (root.manager.wallpaperPaths || []) : []
    readonly property real thumbH: Math.round(root.width * 9 / 16)
    // the hero (page) this column stands in: as tall as the stage
    readonly property Item hero: {
        let p = root.parent;
        while (p && p.objectName !== "pageHero")
            p = p.parent;
        return p;
    }
    readonly property real room: root.hero ? root.hero.height - Space.l : root.thumbH * 3 + Space.s * 2

    implicitHeight: Math.max(root.thumbH * 2, root.room)

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

    ListView {
        id: list
        objectName: "wallpaperStrip"
        width: root.width
        height: root.implicitHeight
        clip: true
        spacing: Space.s
        model: root.paths
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: root.thumbH * 2
        currentIndex: root.paths.indexOf(root.current)
        highlightFollowsCurrentItem: false
        // the one on screen in view (centred when it can be)
        onCurrentIndexChanged: if (currentIndex >= 0)
            Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Contain))

        delegate: ChoiceCard {
            id: card
            required property string modelData
            objectName: "wallpaper:" + root.fileName(card.modelData)
            width: list.width
            previewHeight: root.thumbH
            inset: true
            selected: card.modelData === root.current
            title: card.hovered || card.selected ? root.fileName(card.modelData) : ""
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
                anchors.margins: Space.s
                icon: Icons.play
                role: "secondary"
                tone: "text"
            }
        }

        footer: Item {
            width: list.width
            height: folders.height + Space.s
            Chip {
                id: folders
                objectName: "wallpaperFolders"
                y: Space.s
                width: list.width
                icon: Icons.folder
                text: I18n.t("prefs.wall.section.folders")
                onClicked: SettingsStore.navigate("wallpapers", "folders", "desktop.wallpaperFolders")
            }
        }
    }

    KitText {
        visible: root.paths.length === 0
        width: root.width
        y: Space.l
        role: "secondary"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.t("prefs.wall.empty")
    }
}
