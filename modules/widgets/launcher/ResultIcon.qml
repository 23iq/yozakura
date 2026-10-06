pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config

// The icon tile of a launcher result (list, cards and grid): app icon from
// the icon theme, wallpaper/file thumbnail, or a glyph on a rounded tile.
Item {
    id: tile

    required property var item
    property bool selected: false
    property int size: Metrics.iconSize
    readonly property bool inert: !!item.inert

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

    // Wallpaper / file thumbnail
    ClippingRectangle {
        anchors.fill: parent
        visible: !!tile.item.thumb
        radius: Styling.radius(-6)
        color: Colors.surfaceContainerHigh
        Image {
            anchors.fill: parent
            source: parent.visible ? tile.item.image : ""
            sourceSize: Qt.size(tile.size * 3, tile.size * 3)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    // Glyph
    StyledRect {
        anchors.fill: parent
        visible: !tile.item.image
        variant: tile.selected ? "overprimary" : "common"
        radius: Styling.radius(-6)
        Text {
            anchors.centerIn: parent
            text: tile.item.icon || ""
            font.family: Icons.font
            font.pixelSize: Math.round(tile.size * 0.53)
            color: tile.selected ? Styling.srItem("overprimary") : tile.inert ? Colors.outline : Colors.primary
        }
    }
}
