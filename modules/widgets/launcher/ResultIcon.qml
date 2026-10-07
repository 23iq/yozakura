pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// The icon of a launcher result (rows, cards, grid, detail pane): the app
// icon from the icon theme, a wallpaper / file thumbnail (kit Art), or the
// provider glyph on Art's quiet placeholder tile.
Item {
    id: tile

    required property var item
    property int size: Metrics.iconSize

    implicitWidth: size
    implicitHeight: size

    // App icon from the icon theme
    Image {
        id: themeIcon
        anchors.fill: parent
        visible: !!tile.item.image && !tile.item.thumb
        // Theme icon name, or an absolute path (Icon=/path in .desktop)
        source: !visible ? "" : tile.item.image.charAt(0) === "/" ? "file://" + tile.item.image : "image://icon/" + tile.item.image
        sourceSize: Qt.size(tile.size * 2, tile.size * 2)
        fillMode: Image.PreserveAspectFit
        mipmap: true
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Error)
                source = "image://icon/image-missing";
        }
    }
    Tinted {
        anchors.fill: parent
        visible: themeIcon.visible
        sourceItem: themeIcon
    }

    // Thumbnail, or the glyph on a placeholder tile
    Art {
        anchors.fill: parent
        visible: !themeIcon.visible
        source: tile.item.thumb && tile.item.image ? tile.item.image : ""
        icon: tile.item.icon || Icons.image
    }
}
