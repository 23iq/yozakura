pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.stages

// The picture of a home tile (HomeTile loads it by URL, asynchronously,
// so home shows before any of this is compiled): your wallpaper on a
// Stage, full bleed - swelling and following the pointer while the tile is
// hovered - with, for Desktop layout, the real screen miniature
// (ScreenMini, the same one the page's stage uses), and a scrim so the
// name reads on any wallpaper.
Stage {
    id: art

    // the HomeTile showing this
    required property Card tile
    property bool screen: false

    stageHeight: height
    radius: art.tile.radius
    imageScale: art.tile.hovered ? 1.08 : 1
    imageShift: Qt.point(-art.tile.pointer.x * Space.m, -art.tile.pointer.y * Space.s)

    ScreenMini {
        visible: art.screen
        anchors.fill: parent
        // the dock stays clear of the name under it
        anchors.bottomMargin: art.tile.padding + Space.controlM
        corners: false
        cornerRadius: art.tile.radius
        barOpacity: art.barOpacity
        // at rest the windows would crowd the tile; hovered, they slide in
        // and the miniature comes alive
        showWindows: art.tile.hovered
    }
    Mark {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.5
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Colors.shadow, 0.62)
            }
        }
    }
}
