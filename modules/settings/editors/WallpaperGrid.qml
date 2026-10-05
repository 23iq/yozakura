pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings
import "../../widgets/dashboard/wallpapers/WallpaperFolders.js" as WallFolders
import "../Ui.js" as Ui

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
        spacing: 16

        // Current wallpaper
        Row {
            width: parent.width
            spacing: 18

            ClippingRectangle {
                id: hero
                width: Math.min(parent.width * 0.46, 340)
                height: Math.round(width * 9 / 16)
                radius: Math.min(Styling.radius(2), 18)
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
                Rectangle {
                    visible: root.typeOf(root.current) !== "image" && root.current !== ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    width: badgeRow.implicitWidth + 18
                    height: 22
                    radius: 11
                    color: Ui.alpha(Colors.surfaceContainerLowest, 0.8)
                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.play
                            font.family: Icons.font
                            font.pixelSize: 10
                            color: Colors.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.typeOf(root.current).toUpperCase()
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-4)
                            font.weight: Font.Bold
                            color: Colors.overBackground
                        }
                    }
                }
            }

            Column {
                width: parent.width - hero.width - parent.spacing
                anchors.verticalCenter: hero.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: I18n.t("prefs.wall.now_showing").toUpperCase()
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-4)
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: Colors.primary
                }
                Text {
                    width: parent.width
                    text: root.fileName(root.current) || I18n.t("prefs.wall.none")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(2)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                    elide: Text.ElideMiddle
                }
                Text {
                    width: parent.width
                    text: root.current ? root.current.substring(0, root.current.lastIndexOf("/")) : ""
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-3)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideMiddle
                }
                Text {
                    width: parent.width
                    text: root.folders.length > 1 ? I18n.t("prefs.wall.count", root.allPaths.length, root.folders.length) : I18n.t("prefs.wall.count_one", root.allPaths.length)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
                Item {
                    width: 1
                    height: 4
                }
                Row {
                    spacing: 8
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

        // Folder filter
        Flow {
            width: parent.width
            spacing: 6
            visible: root.folders.length > 1

            Repeater {
                model: [""].concat(root.folders)
                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool active: root.folderFilter === modelData
                    width: chipLabel.implicitWidth + 26
                    height: 30
                    radius: 15
                    color: active ? Colors.primary : (chipArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : Ui.alpha(Colors.overBackground, 0.06))
                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData === "" ? I18n.t("prefs.wall.all") : chip.modelData.substring(chip.modelData.lastIndexOf("/") + 1)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Medium
                        color: chip.active ? Colors.overPrimary : Colors.overBackground
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.folderFilter = chip.modelData
                    }
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
                    anchors.margins: 4
                    radius: Math.min(Styling.radius(0), 14)
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
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Text {
                        visible: root.typeOf(tile.modelData) === "video"
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        text: Icons.play
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: "white"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Math.min(Styling.radius(0), 14) + 2
                    color: "transparent"
                    border.width: tile.selected ? 3 : 0
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

        Text {
            visible: root.paths.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("prefs.wall.empty")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }
}
