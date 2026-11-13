pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "HomeStatus.js" as HomeStatus
import "schema/Categories.js" as Categories
import "Registry.js" as Registry

// One destination on the home bento (a kit Card). Screen is a picture: the
// screen miniature on your wallpaper, full bleed under a scrim; Look a
// scene (a big "Aa" in the UI font, its name, the palette). Every other
// tile is its icon on a plate at the top left with what it holds (its
// tabs) beside it, and at the foot its name and one live status line
// (HomeStatus.js). Scenes are loaded by URL and asynchronously once home
// has shown its first frame (`live`), so home compiles none of them before
// it is visible. Hover lifts the tile and tints the plate; a click / Enter
// opens it.
Card {
    id: tile

    // a Categories.home() entry: {id, icon, title, w, h, hero}
    required property var destination
    // false until home has shown its first frame
    property bool live: true
    readonly property string kind: destination.id
    readonly property bool picture: tile.kind === "screen"
    readonly property string sceneFile: Registry.scene(tile.kind)
    // no scene (a destination a picture would not explain at tile size):
    // its icon on a plate at the top left, what is inside beside it, the
    // name and status at the foot (one layout for every such tile)
    readonly property bool glyph: tile.sceneFile === ""
    // what the destination holds: its tabs, by name
    // (the first three, then "+N": a whole short line, never cut mid-word)
    readonly property var tabNames: (tile.destination.categories || []).map(id => {
        const c = Categories.byId(id);
        return c ? I18n.t(c.title) : "";
    }).filter(t => t !== "")
    readonly property string contents: tile.tabNames.slice(0, 3).join(" · ") + (tile.tabNames.length > 3 ? " · +" + (tile.tabNames.length - 3) : "")
    readonly property string status: tile.live ? HomeStatus.line(tile.destination.id, {
        "get": k => SettingsStore.get(k),
        "tr": k => I18n.t(k),
        "wallpapers": GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperPaths ? GlobalStates.wallpaperManager.wallpaperPaths.length : 0,
        "preset": tile.destination.id === "look" ? (PresetStatusService.active || "") : "",
        "outputs": tile.destination.id === "devices" ? DisplaysService.outputs : [],
        "network": tile.destination.id === "devices" ? (NetworkService.networkName || (NetworkService.ethernet ? "Ethernet" : "")) : "",
        "volume": tile.destination.id === "devices" && Audio.sink ? Number(Audio.sink?.audio?.volume ?? -1) : -1,
        "language": tile.destination.id === "system" ? ((I18n.availableLanguages || {})[I18n.resolvedLanguage] || "") : "",
        "update": tile.destination.id === "system" ? UpdateService.updateAvailable === true : false
    }) : ""

    objectName: "homeTile:" + destination.id
    interactive: true
    fill: !tile.picture
    accented: false
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(destination.title)
    Accessible.description: tile.status

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

        // the destination's icon on a tonal plate (glyph tiles)
        Mark {
            id: plate
            objectName: "homeTileIcon"
            visible: tile.glyph
            // a small tile: never into the name under it
            width: Math.round(Math.max(Type.iconSize("title") * 1.8, Math.min(Type.iconSize("title") * 2.4, body.height - label.height - Space.m)))
            height: width
            radius: Look.radius("control", height)
            color: tile.hovered || tile.activeFocus ? Look.tonal(Type.accent) : Qt.alpha(Type.text, 0.08)
            Behavior on color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
            Icon {
                anchors.centerIn: parent
                icon: Icons[tile.destination.icon] ?? ""
                role: "title"
                size: Math.round(Type.iconSize("title") * 1.3)
                tone: tile.hovered || tile.activeFocus ? "accent" : "text"
            }
        }

        // what is inside (its tabs), beside the plate: where a wide tile
        // would otherwise be blank
        KitText {
            objectName: "homeTileContents"
            // whole or not at all: shown only where it fits beside the plate
            visible: tile.glyph && tile.contents !== "" && width >= Space.px(120) && implicitHeight <= plate.height * 1.25
            x: plate.width + Space.m
            y: Math.round((plate.height - height) / 2)
            width: body.width - x
            role: "caption"
            text: tile.contents
            wrapMode: Text.WordWrap
        }

        Scene {
            objectName: "homeTileScene"
            wanted: !tile.picture && !tile.glyph
            visible: !tile.glyph
            width: body.width
            height: Math.max(0, body.height - label.height - Space.m)
        }

        Column {
            id: label
            y: body.height - height
            width: body.width
            spacing: Space.hairline

            KitText {
                width: parent.width
                role: "title"
                text: I18n.t(tile.destination.title)
                color: tile.picture ? Qt.rgba(1, 1, 1, 1) : Type.text
                // a narrow tile: the name wraps, whole ("Notifications &
                // focus"), never cut
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            KitText {
                objectName: "homeTileStatus"
                width: parent.width
                role: "secondary"
                text: tile.status
                color: tile.picture ? Qt.rgba(1, 1, 1, 0.8) : Type.secondary
                // a long status wraps onto a second line, whole
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideNone
            }
        }
    }
}
