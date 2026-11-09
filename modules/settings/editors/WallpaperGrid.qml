pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings
import "../../widgets/dashboard/wallpapers/WallpaperFolders.js" as WallFolders
import "../Ui.js" as Ui
import qs.modules.components.kit

// Current wallpaper + thumbnails of every folder; click to apply.
Item {
    id: root

    property var entry
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string current: manager ? (manager.currentWallpaper || "") : ""
    readonly property var folders: manager && manager.scanDirs ? manager.scanDirs : (manager ? [manager.wallpaperDir] : [])
    readonly property var allPaths: manager ? (manager.wallpaperPaths || []) : []
    property string folderFilter: ""
    readonly property var paths: folderFilter === "" ? allPaths : allPaths.filter(p => WallFolders.isInside(p, folderFilter))
    readonly property int columns: Math.max(3, Math.floor(width / 150))
    readonly property real cell: width / columns

    implicitHeight: column.implicitHeight

    // A removed folder (or a single remaining one, which hides the chips)
    // must not leave an empty grid behind.
    onFoldersChanged: {
        if (folderFilter !== "" && (folders.length < 2 || folders.indexOf(folderFilter) < 0))
            folderFilter = "";
    }

    function typeOf(path) {
        return manager && manager.getFileType ? manager.getFileType(path) : "image";
    }

    // Images load directly (downscaled); videos/GIFs use the cached
    // full-size lockscreen frame when big, else the thumbnail.
    function thumb(path, big) {
        if (!path || !manager)
            return "";
        if (typeOf(path) === "image")
            return "file://" + path;
        if (big && manager.getLockscreenFramePath)
            return "file://" + manager.getLockscreenFramePath(path);
        return "file://" + manager.getDisplaySource(path);
    }

    function fileName(path) {
        return path ? path.substring(path.lastIndexOf("/") + 1) : "";
    }

    Column {
        id: column
        width: parent.width
        spacing: Space.l

        // Current wallpaper
        Row {
            width: parent.width
            spacing: Space.l

            ClippingRectangle {
                id: hero
                width: Math.min(parent.width * 0.46, 340)
                height: Math.round(width * 9 / 16)
                radius: Look.radius("box")
                color: Colors.surfaceContainerHigh

                Image {
                    id: heroImage
                    anchors.fill: parent
                    source: root.thumb(root.current, true)
                    sourceSize.width: 720
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // No cached frame yet: fall back to the thumbnail.
                    onStatusChanged: if (status === Image.Error && root.current)
                        source = root.thumb(root.current, false)
                }
                // Video / GIF badge over the artwork
                StyledRect {
                    visible: root.typeOf(root.current) !== "image" && root.current !== ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Space.m
                    variant: "popup"
                    enableShadow: false
                    width: badgeRow.implicitWidth + Space.m * 2
                    height: badgeRow.implicitHeight + Space.xs * 2
                    radius: Look.radius("round", height)
                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: Space.xs
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Icons.play
                            role: "caption"
                            tone: "text"
                        }
                        KitText {
                            role: "label"
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.typeOf(root.current)
                            color: Type.text
                        }
                    }
                }
            }

            Column {
                width: parent.width - hero.width - parent.spacing
                anchors.verticalCenter: hero.verticalCenter
                spacing: Space.s

                KitText {
                    role: "label"
                    width: parent.width
                    text: I18n.t("prefs.wall.now_showing")
                }
                KitText {
                    role: "title"
                    width: parent.width
                    text: root.fileName(root.current) || I18n.t("prefs.wall.none")
                    font.weight: Font.Bold
                    elide: Text.ElideMiddle
                }
                KitText {
                    role: "caption"
                    width: parent.width
                    text: root.current ? root.current.substring(0, root.current.lastIndexOf("/")) : ""
                    font.family: Type.monoFont
                    color: Type.secondary
                    elide: Text.ElideMiddle
                }
                KitText {
                    role: "caption"
                    width: parent.width
                    text: root.folders.length > 1 ? I18n.t("prefs.wall.count", root.allPaths.length, root.folders.length) : I18n.t("prefs.wall.count_one", root.allPaths.length)
                }
                Item {
                    width: 1
                    height: Space.xs
                }
                Row {
                    spacing: Space.s
                    PillButton {
                        icon: "caretLeft"
                        kind: "ghost"
                        text: I18n.t("prefs.wall.previous")
                        enabled: root.allPaths.length > 1
                        onClicked: root.manager.previousWallpaper()
                    }
                    PillButton {
                        icon: "caretRight"
                        kind: "ghost"
                        text: I18n.t("prefs.wall.next")
                        enabled: root.allPaths.length > 1
                        onClicked: root.manager.nextWallpaper()
                    }
                }
            }
        }

        WallpaperScreens {
            width: parent.width
        }

        // Folder filter
        Flow {
            width: parent.width
            spacing: Space.s
            visible: root.folders.length > 1

            Repeater {
                model: [""].concat(root.folders)
                delegate: Chip {
                    id: chip
                    required property string modelData
                    dense: true
                    active: root.folderFilter === modelData
                    text: modelData === "" ? I18n.t("prefs.wall.all") : modelData.substring(modelData.lastIndexOf("/") + 1)
                    onClicked: root.folderFilter = chip.modelData
                }
            }
        }

        GridView {
            id: grid
            objectName: "wallpaperGrid"
            width: parent.width
            height: Math.min(Math.ceil(count / root.columns), 3) * cellHeight
            cellWidth: root.cell
            cellHeight: Math.round(root.cell * 0.66)
            model: root.paths
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: Math.ceil(count / root.columns) > 3
            cacheBuffer: cellHeight * 2

            delegate: Item {
                id: tile
                required property string modelData
                readonly property bool selected: modelData === root.current
                width: grid.cellWidth
                height: grid.cellHeight

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Space.xs
                    radius: Look.radius("control")
                    color: Colors.surfaceContainerHigh

                    Image {
                        anchors.fill: parent
                        source: root.thumb(tile.modelData, false)
                        sourceSize.width: 320
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        scale: tileArea.containsMouse ? 1.06 : 1
                        Behavior on scale {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Motion.morph.duration
                                easing.type: Motion.morph.easing
                            }
                        }
                    }
                    Icon {
                        visible: root.typeOf(tile.modelData) === "video"
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Space.s
                        icon: Icons.play
                        role: "secondary"
                        tone: "text"
                        style: Text.Raised
                        styleColor: Ui.alpha(Colors.shadow, 0.6)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Space.xs / 2
                    radius: Look.radius("control") + Space.xs / 2
                    color: "transparent"
                    border.width: tile.selected ? Space.stroke : 0
                    border.color: Colors.primary
                }
                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.manager.setWallpaper(tile.modelData)
                }
            }
        }

        KitText {
            role: "secondary"
            visible: root.paths.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("prefs.wall.empty")
        }
    }
}
