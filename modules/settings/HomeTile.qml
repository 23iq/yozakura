pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "HomeStatus.js" as HomeStatus
import "Registry.js" as Registry
import "../services/KeyboardModel.js" as KeyboardModel

// One destination on the home bento (a kit Card in the language's own
// box). Screen and Look are scenes (home/<X>Scene.qml): your screen as a
// small monitor on the card, the UI font and the palette; every other tile
// is its icon on a plate at the top left. At the foot of each: its name and
// one live status line (HomeStatus.js) that never wraps; the line's room is
// there from the first frame, the words fade in when home is warm. Where
// the language has instruments (device), a lit LED sits in the corner.
// Scenes are loaded by URL and asynchronously once home has shown its first
// frame (`live`), so home compiles none of them before it is visible.
// Hover lifts the tile and tints the plate; a click / Enter opens it.
Card {
    id: tile

    // a Categories.home() entry: {id, icon, title, w, h, hero}
    required property var destination
    // false until home has shown its first frame
    property bool live: true
    readonly property string kind: destination.id
    readonly property string sceneFile: Registry.scene(tile.kind)
    // no scene: the icon on a plate at the top left
    readonly property bool glyph: tile.sceneFile === ""
    // The screen monitor beside the name where the tile is wide enough for
    // both (side by side: the name and its line centred on the left, the
    // monitor as tall as the card holds, centred in the rest), else above it.
    readonly property real monitorAspect: 16 / 9
    readonly property real sideLabelWidth: Math.max(Space.px(190), body.width * 0.28)
    readonly property real sideMonitorWidth: Math.min(body.width - tile.sideLabelWidth - Space.xl, body.height * tile.monitorAspect)
    readonly property bool side: tile.kind === "screen" && tile.sideMonitorWidth >= Space.px(320)
    readonly property string status: tile.live ? HomeStatus.line(tile.destination.id, {
        "get": k => SettingsStore.get(k),
        "tr": k => I18n.t(k),
        "wallpapers": GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperPaths ? GlobalStates.wallpaperManager.wallpaperPaths.length : 0,
        "preset": tile.destination.id === "look" ? (PresetStatusService.active || "") : "",
        "outputs": tile.destination.id === "devices" ? DisplaysService.outputs : [],
        "network": tile.destination.id === "devices" ? (NetworkService.networkName || (NetworkService.ethernet ? "Ethernet" : "")) : "",
        "volume": tile.destination.id === "devices" && Audio.sink ? Number(Audio.sink?.audio?.volume ?? -1) : -1,
        "language": tile.destination.id === "system" ? ((I18n.availableLanguages || {})[I18n.resolvedLanguage] || "") : "",
        "update": tile.destination.id === "system" ? UpdateService.updateAvailable === true : false,
        "version": tile.destination.id === "system" ? (UpdateService.currentVersion || "") : "",
        "layoutName": tile.destination.id === "keys" ? (code => KeyboardModel.layoutInfo(KeyboardService.catalog, code)?.description ?? "") : null
    }) : ""
    onLiveChanged: {
        // the layout names of the Keyboard line (the catalog is read once)
        if (tile.live && tile.kind === "keys")
            KeyboardService.loadCatalog();
    }

    objectName: "homeTile:" + destination.id
    interactive: true
    accented: false
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(destination.title)
    Accessible.description: tile.status

    // A scene, by URL, asynchronously, fading in once it is there.
    component Scene: Loader {
        id: scene
        active: tile.live && tile.sceneFile !== ""
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

    Item {
        id: body
        width: tile.contentWidth
        height: tile.height - tile.padding * 2

        // the destination's icon on a plate (glyph tiles), in the
        // language's control box: a hairline ring where boxes are
        // hairlines, a tonal box, a solid tile, an instrument's well
        Mark {
            id: plate
            objectName: "homeTileIcon"
            visible: tile.glyph
            // a small tile: never into the name under it
            width: Math.round(Math.max(Type.iconSize("title") * 1.8, Math.min(Type.iconSize("title") * 2.4, body.height - label.height - Space.m)))
            height: width
            radius: Look.radius("control", height)
            color: tile.hovered || tile.activeFocus ? Look.tonal(Type.accent) : (Look.ledIndicator ? Look.wellFill : (Look.groupBoxed || Look.boxedControls ? Look.raisedFill(false) : "transparent"))
            border.width: Look.groupBoxed || Look.boxedControls ? (Look.controlEdge.a > 0 ? Space.hairline : 0) : Space.hairline
            border.color: Look.boxedControls ? Look.controlEdge : Type.hairline
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

        Scene {
            objectName: "homeTileScene"
            visible: !tile.glyph
            // side by side: the room right of the name, the monitor centred in it
            x: tile.side ? tile.sideLabelWidth + Space.xl : 0
            width: tile.side ? body.width - x : body.width
            height: tile.side ? body.height : Math.max(0, body.height - label.height - Space.m)
        }

        Column {
            id: label
            y: tile.side ? Math.round((body.height - height) / 2) : body.height - height
            width: tile.side ? tile.sideLabelWidth : body.width
            spacing: tile.side ? Space.xs : Space.hairline

            KitText {
                width: parent.width
                role: "title"
                // the hero tile's name a step up, beside its picture
                font.pixelSize: tile.side ? Math.round(Type.size("title") * 1.3) : Type.size("title")
                text: I18n.t(tile.destination.title)
                // a narrow tile: the name wraps, whole ("Notifications &
                // focus"), never cut
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            KitText {
                id: statusText
                objectName: "homeTileStatus"
                width: parent.width
                role: "secondary"
                // one line from the first frame (a blank while it is not
                // live yet), so the name above never jumps; whole parts
                // only, as many as fit (HomeStatus.fit)
                text: tile.status !== "" ? HomeStatus.fit(tile.status, s => statusMetrics.advanceWidth(s), statusText.width - statusText.leftPadding) : " "
                FontMetrics {
                    id: statusMetrics
                    font: statusText.font
                }
                maximumLineCount: 1
                elide: Text.ElideRight
                // room for the LED before the words
                leftPadding: Look.ledIndicator ? Space.s * 2 : 0
                opacity: tile.status !== "" ? 1 : 0
                Behavior on opacity {
                    enabled: Motion.glide.duration > 0
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }

                // an instrument's status LED (device), lit before the line
                Item {
                    objectName: "homeTileLed"
                    visible: Look.ledIndicator
                    y: Math.round((parent.height - height) / 2)
                    width: Space.s
                    height: Space.s
                    RectangularShadow {
                        anchors.fill: parent
                        radius: width / 2
                        blur: Space.s
                        spread: 0
                        color: Qt.alpha(Type.accent, 0.7)
                    }
                    Mark {
                        anchors.fill: parent
                        color: Type.accent
                    }
                }
            }
        }
    }
}
