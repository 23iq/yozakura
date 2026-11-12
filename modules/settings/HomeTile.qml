pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.stages
import "HomeStatus.js" as HomeStatus

// One destination on the home bento: a kit Card that is live content, not
// an icon with a name. Desktop layout is the real screen miniature (the
// same ScreenMini the page's stage uses), Wallpaper is your wallpaper
// (it swells and follows the pointer while hovered, a parallax), Look
// shows the palette; every other tile carries its icon. All carry the name
// and one live status line (HomeStatus.js). Hover lifts the tile (and
// slides windows into the miniature); a click / Enter opens it.
Card {
    id: tile

    // a Categories.home() entry: {id, icon, title, size}
    required property var destination
    readonly property string kind: destination.id === "layout" ? "screen" : (destination.id === "wallpaper" ? "wallpaper" : (destination.id === "look" ? "palette" : "icon"))
    readonly property bool picture: tile.kind === "screen" || tile.kind === "wallpaper"
    readonly property string status: HomeStatus.line(tile.destination.id, {
        "get": k => SettingsStore.get(k),
        "tr": k => I18n.t(k),
        "wallpapers": GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperPaths ? GlobalStates.wallpaperManager.wallpaperPaths.length : 0,
        "preset": PresetStatusService.active || ""
    })

    objectName: "homeTile:" + destination.id
    interactive: true
    fill: !tile.picture
    Accessible.name: I18n.t(destination.title)

    // The picture tiles: the real miniature / the wallpaper, full bleed.
    background: Loader {
        anchors.fill: parent
        active: tile.picture
        sourceComponent: Stage {
            id: stage
            anchors.fill: parent
            stageHeight: parent.height
            radius: tile.radius
            // hovered: the wallpaper swells a little and follows the pointer
            imageScale: tile.hovered ? 1.08 : 1
            imageShift: Qt.point(-tile.pointer.x * Space.m, -tile.pointer.y * Space.s)

            ScreenMini {
                anchors.fill: parent
                // the dock stays clear of the name under it
                anchors.bottomMargin: tile.padding + Space.controlM
                corners: false
                visible: tile.kind === "screen"
                barOpacity: stage.barOpacity
                cornerRadius: tile.radius
                // at rest the windows would crowd the tile; hovered, they
                // slide in and the miniature comes alive
                showWindows: tile.hovered
            }
            // a scrim so the name reads on any wallpaper
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
    }

    Item {
        width: tile.contentWidth
        height: tile.height - tile.padding * 2

        Icon {
            visible: !tile.picture
            icon: Icons[tile.destination.icon] ?? ""
            role: "title"
            tone: "accent"
        }

        // Look: the palette, as swatches
        Row {
            visible: tile.kind === "palette"
            anchors.right: parent.right
            spacing: Space.s
            Repeater {
                model: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.surfaceContainerHighest]
                delegate: Mark {
                    required property color modelData
                    width: Space.controlXS
                    height: width
                    color: modelData
                    border.width: Space.hairline
                    border.color: Type.hairline
                }
            }
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Space.hairline

            KitText {
                width: parent.width
                role: "title"
                text: I18n.t(tile.destination.title)
                color: tile.picture ? Qt.rgba(1, 1, 1, 1) : Type.text
                elide: Text.ElideRight
            }
            KitText {
                objectName: "homeTileStatus"
                width: parent.width
                role: "secondary"
                text: tile.status
                color: tile.picture ? Qt.rgba(1, 1, 1, 0.82) : Type.secondary
                elide: Text.ElideRight
            }
        }
    }
}
