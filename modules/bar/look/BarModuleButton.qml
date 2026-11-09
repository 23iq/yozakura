import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look

// A bar module that is one button (launcher, presets, tools, power): the
// bar's module box (ModuleBox: a piece of its group shape, the language's
// hover, `active` = the accent state while its panel is open) around a kit
// Icon. A `glyph` longer than one character is an image path (the launcher
// logo), drawn at `imageSize` and tinted with `tint`. The kit IconButton is
// not used here: bar modules join their neighbours' group box
// (startRadius / endRadius), a free-standing control box cannot.
Button {
    id: root

    property string glyph: ""
    property bool tint: false
    property int imageSize: Type.iconSize("title")
    property bool active: false
    property bool vertical: false
    property bool enableShadow: true
    property real startRadius: 0
    property real endRadius: 0
    property string tooltipText: ""
    // Bar panels: module size; Button.flat drops the box
    property int size: BarMetrics.moduleSize
    readonly property bool isImage: root.glyph.length > 1 && root.glyph.indexOf("<") !== 0

    implicitWidth: root.size
    implicitHeight: root.size
    Accessible.name: root.tooltipText

    background: ModuleBox {
        id: box
        vertical: root.vertical
        startRadius: root.startRadius
        endRadius: root.endRadius
        flat: root.flat
        shadow: root.enableShadow && Config.showBackground
        active: root.active
        hovered: root.hovered || root.pressed
    }

    contentItem: Item {
        Icon {
            objectName: "moduleGlyph"
            visible: !root.isImage
            anchors.fill: parent
            icon: root.glyph
            size: BarLook.iconSize(root.size)
            color: box.ink
        }

        Item {
            visible: root.isImage
            anchors.centerIn: parent
            readonly property real side: (BarMetrics.compact || root.size < BarMetrics.moduleSize) ? Math.min(root.imageSize, root.size - Space.s) : root.imageSize
            width: side
            height: side

            Image {
                id: image
                anchors.fill: parent
                source: root.isImage ? root.glyph : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Tinted {
                anchors.fill: parent
                sourceItem: image
                active: root.tint
                fullTint: root.tint
            }
        }
    }
}
