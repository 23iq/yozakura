pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.globals
import qs.config

// One thumbnail of the wallpapers tab grid. The thumbnail (never the
// original file) is only loaded while the cell is near the viewport and the
// dashboard is open. Hover selects, click applies (per screen if enabled).
Rectangle {
    id: cell

    required property string modelData
    required property int index
    // The WallpapersTab (selection, per-screen state, margins) and its grid.
    required property var tab
    required property GridView grid
    // Same as the grid's isScrolling: no hover/animation while dragged or flicked.
    readonly property bool scrolling: grid.dragging || grid.flicking

    width: cell.grid.cellWidth
    height: cell.grid.cellHeight
    color: "transparent"

    property bool isCurrentWallpaper: cell.tab.screenWallpaper === cell.modelData

    property bool isHovered: false
    property bool isSelected: cell.tab.selectedIndex === cell.index

    // Calcular si el item está visible en el viewport (con buffer para precarga)
    readonly property bool isInViewport: {
        var gridTop = cell.grid.contentY;
        var gridBottom = gridTop + cell.grid.height;
        var itemTop = y;
        var itemBottom = itemTop + height;

        // Buffer de una fila arriba y abajo para precarga suave
        var buffer = cell.grid.cellHeight;
        return itemBottom + buffer >= gridTop && itemTop - buffer <= gridBottom;
    }

    // Contenedor de imagen optimizado con ClippingRectangle para radius
    Item {
        anchors.fill: parent
        anchors.margins: cell.tab.wallpaperMargin

        ClippingRectangle {
            anchors.fill: parent
            color: Colors.surface
            radius: Styling.radius(4)

            // Lazy loader que solo carga cuando el item está visible
            Loader {
                id: thumbLoader
                anchors.fill: parent
                sourceComponent: thumbnailComponent
                property string sourceFile: cell.modelData
                active: cell.isInViewport && cell.tab.visible && GlobalStates.dashboardOpen
                asynchronous: true

                // Placeholder mientras carga
                Rectangle {
                    anchors.fill: parent
                    color: Colors.surface
                    visible: !thumbLoader.active || thumbLoader.status !== Loader.Ready

                    Text {
                        id: spinner
                        anchors.centerIn: parent
                        text: Icons.circleNotch
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Colors.overSurfaceVariant
                        rotation: 0

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: spinner.parent.visible
                        }
                    }
                }
            }
        }
    }

    // Manejo de eventos de ratón.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: !cell.scrolling
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            if (cell.scrolling)
                return;
            cell.isHovered = true;
            cell.tab.setSelectedIndex(cell.index);
        }
        onExited: {
            cell.isHovered = false;
        }
        onPressed: {
            if (!cell.scrolling)
                cell.scale = 0.95;
        }
        onReleased: cell.scale = 1.0

        onClicked: mouse => {
            if (cell.scrolling)
                return;
            if (GlobalStates.wallpaperManager) {
                GlobalStates.setWallpaperTransitionOrigin(cell, mouse.x, mouse.y, cell.tab.currentScreenName);
                if (cell.tab.isPerScreen && cell.tab.currentScreenName !== "") {
                    GlobalStates.wallpaperManager.setWallpaper(cell.modelData, cell.tab.currentScreenName);
                } else {
                    GlobalStates.wallpaperManager.setWallpaper(cell.modelData);
                }
            }
        }
    }

    // Animaciones de color y escala.
    Behavior on color {
        enabled: Config.animDuration > 0
        ColorAnimation {
            duration: Config.animDuration / 2
            easing.type: Motion.morph.easing
        }
    }

    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Motion.morph.easing
        }
    }

    // Thumbnail image (decoded at cell size, cached).
    Component {
        id: thumbnailComponent
        Image {
            mipmap: true
            source: {
                if (!thumbLoader.sourceFile || !GlobalStates.wallpaperManager)
                    return "";

                // Usar SOLAMENTE thumbnail, nunca el original (muy pesado)
                var thumbnailPath = GlobalStates.wallpaperManager.getThumbnailPath(thumbLoader.sourceFile);
                var version = GlobalStates.wallpaperManager.thumbnailsVersion;
                return "file://" + thumbnailPath + "?v=" + version;
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: true // Cache the decoded thumbnails: with cache:false every
            // grid open re-decodes all 621 thumbs and the global pixmap cache
            // retains the (old) decoded entries, growing per open instead of
            // reusing them.
            sourceSize.width: cell.grid.cellWidth
            sourceSize.height: cell.grid.cellHeight
        }
    }
}
