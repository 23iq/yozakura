pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services.activities
import "Downloads.js" as Downloads

// A Downloads stack (macOS dock style): the latest files piled on the
// module; clicking opens the downloads list (DownloadsList: in progress +
// recent files). moduleOptions.downloads: folder ("" = ~/Downloads), count.
BarModuleBase {
    id: root

    moduleKey: "downloads"

    readonly property string folder: options.folder ? String(options.folder) : Quickshell.env("HOME") + "/Downloads"
    readonly property int count: Math.max(1, Math.min(12, options.count !== undefined ? options.count : 8))
    readonly property var files: {
        const out = [];
        for (let i = 0; i < model.count && out.length < count; i++) {
            const name = model.get(i, "fileName");
            if (!Downloads.isPartial(name))
                out.push({
                    "name": name,
                    "url": model.get(i, "fileUrl").toString()
                });
        }
        return out;
    }
    readonly property bool fanOpen: fanPopup.isOpen
    function toggleFan() {
        fanPopup.toggle();
    }

    contentLength: moduleSize

    FolderListModel {
        id: model
        folder: "file://" + root.folder
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Time
    }

    BarModuleSurface {
        id: surface
        module: root
        hovered: mouse.containsMouse
        active: fanPopup.isOpen
        // Docks draw the stack on the dock itself
        visible: root.panelStyle !== "dock"
    }

    // The pile: up to three latest files, slightly fanned
    Item {
        id: pile
        anchors.centerIn: parent
        width: Math.round(root.moduleSize * (root.panelStyle === "dock" ? 0.8 : 0.62))
        height: width

        // Nothing downloaded yet: the kit glyph (an icon theme may lack
        // folder-download, which left an empty box)
        Text {
            objectName: "downloadsEmptyGlyph"
            anchors.centerIn: parent
            visible: root.files.length === 0
            text: Icons.downloadSimple
            font.family: Icons.font
            font.pixelSize: root.iconSize
            color: surface.foreground
        }

        Repeater {
            model: Math.min(3, root.files.length)
            delegate: FileTile {
                required property int index
                // Back to front
                readonly property int depth: Math.min(3, root.files.length) - 1 - index
                file: root.files[depth]
                size: pile.width * 0.86
                x: (pile.width - size) / 2 + depth * pile.width * 0.05
                y: (pile.height - size) / 2 - depth * pile.width * 0.05
                rotation: depth === 0 ? 0 : (depth % 2 === 1 ? -7 : 6)
                opacity: depth === 0 ? 1 : 0.85
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleFan()
    }

    StyledToolTip {
        show: mouse.containsMouse && !fanPopup.isOpen
        tooltipText: I18n.t("bar.downloads.tooltip")
    }

    BarPopup {
        id: fanPopup
        objectName: "downloadsPopup"
        anchorItem: surface
        bar: root.bar
        popupPadding: Look.surfacePadding
        contentWidth: 320 + popupPadding * 2
        contentHeight: list.implicitHeight + popupPadding * 2

        DownloadsList {
            id: list
            width: parent.width
            files: root.files
            transfers: ActivityService.transfers ?? []
            folder: root.folder
            onOpened: fanPopup.close()
        }
    }

    component FileTile: Item {
        id: tile
        property var file: null
        property real size: 32
        width: size
        height: size

        Rectangle {
            anchors.fill: parent
            visible: tile.file !== null && Downloads.isImage(tile.file.name)
            radius: 4
            color: "white"
            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: parent.visible ? tile.file.url : ""
                sourceSize: Qt.size(tile.size * 2, tile.size * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        // The theme's type icon; Quickshell.iconPath(.., true) is "" when the
        // theme lacks it, then a kit file glyph (never a blank tile)
        readonly property string themeIcon: tile.file !== null && !Downloads.isImage(tile.file.name) ? Quickshell.iconPath(Downloads.iconFor(tile.file.name), true) : ""
        Image {
            anchors.fill: parent
            visible: tile.themeIcon !== ""
            source: tile.themeIcon
            sourceSize: Qt.size(tile.size * 2, tile.size * 2)
        }
        Text {
            anchors.centerIn: parent
            visible: tile.file !== null && !Downloads.isImage(tile.file.name) && tile.themeIcon === ""
            text: Icons.file
            font.family: Icons.font
            font.pixelSize: root.iconSize
            color: surface.foreground
        }
    }
}
