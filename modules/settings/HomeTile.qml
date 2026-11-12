pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "HomeStatus.js" as HomeStatus
import "Registry.js" as Registry

// One destination on the home bento: a kit Card that is a small live
// scene of what it opens, drawn from real state (home/<Scene>.qml: the
// screen miniature, the palette and the UI font, the wallpaper, a toast in
// its corner, the lock clock, preset cards, a launcher, widgets, a chat,
// keycaps, the monitors, tiled windows), its name as a heading and one live
// status line (HomeStatus.js). Desktop layout, Wallpaper and Lock screen are
// pictures, full bleed under a scrim; the others draw their scene above
// the name (beside it in a short wide tile). Scenes are loaded by URL and
// asynchronously once home has shown its first frame (`live`), so home
// compiles none of them before it is visible. Hover lifts the tile (the
// wallpaper swells and follows the pointer); a click / Enter opens it.
Card {
    id: tile

    // a Categories.home() entry: {id, icon, title, w, h, hero}
    required property var destination
    // false until home has shown its first frame
    property bool live: true
    readonly property string kind: destination.id
    readonly property bool picture: ["layout", "wallpaper", "lockscreen"].indexOf(tile.kind) >= 0
    // a short wide tile: the scene beside the name, not above it
    readonly property bool side: (destination.h || 4) <= 3
    readonly property string sceneFile: Registry.scene(tile.kind)
    readonly property string status: tile.live ? HomeStatus.line(tile.destination.id, {
        "get": k => SettingsStore.get(k),
        "tr": k => I18n.t(k),
        "wallpapers": GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperPaths ? GlobalStates.wallpaperManager.wallpaperPaths.length : 0,
        "preset": tile.destination.id === "presets" ? (PresetStatusService.active || "") : "",
        "outputs": tile.destination.id === "displays" ? DisplaysService.outputs : []
    }) : ""

    objectName: "homeTile:" + destination.id
    interactive: true
    fill: !tile.picture
    accented: tile.destination.hero === true
    Accessible.name: I18n.t(destination.title)

    // A scene, by URL, asynchronously, fading in once it is there.
    component Scene: Loader {
        id: scene
        property bool wanted: false
        active: scene.wanted && tile.live && tile.sceneFile !== ""
        asynchronous: true
        opacity: scene.status === Loader.Ready ? 1 : 0
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        function load() {
            if (scene.active && !scene.item)
                scene.setSource(Qt.resolvedUrl(tile.sceneFile), {
                    "tile": tile
                });
        }
        onActiveChanged: scene.load()
        Component.onCompleted: scene.load()
    }

    // the pictures: full bleed under everything
    background: Scene {
        objectName: "homeTileScene"
        anchors.fill: parent
        wanted: tile.picture
    }

    Item {
        id: body
        width: tile.contentWidth
        height: tile.height - tile.padding * 2

        Scene {
            objectName: "homeTileScene"
            wanted: !tile.picture
            x: tile.side ? body.width * 0.5 : 0
            width: tile.side ? body.width * 0.5 : body.width
            height: tile.side ? body.height : Math.max(0, body.height - label.height - Space.m)
        }

        Column {
            id: label
            anchors.bottom: parent.bottom
            width: tile.side ? body.width * 0.5 - Space.s : body.width
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
                color: tile.picture ? Qt.rgba(1, 1, 1, 0.8) : Type.secondary
                elide: Text.ElideRight
            }
        }
    }
}
