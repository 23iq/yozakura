pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.config
import qs.modules.globals
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// A preset's thumbnail: the miniature shell on the current wallpaper,
// cached as a PNG per wallpaper + look + palette + size
// (<cache>/preset-thumbs/<md5>.png). A missing image is rendered lazily
// (at most PresetStudio.maxRendering at once) and saved; a skeleton
// shimmers until something can be shown.
Item {
    id: root

    property var look: null

    objectName: "presetThumb"

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaperFile: manager ? (manager.currentWallpaper || "") : ""
    readonly property string wallpaper: manager && wallpaperFile && manager.getDisplaySource ? manager.getDisplaySource(wallpaperFile) : wallpaperFile
    readonly property var colors: PresetModel.paletteFor(look, SchemePreviews.palettes)
    // Wait for the scheme palettes unless they cannot come.
    readonly property bool inputsReady: look !== null && PresetStudio.thumbIndexReady && (colors !== null || SchemePreviews.failed || SchemePreviews.source === "" || (!SchemePreviews.loading && SchemePreviews.loadedSource === SchemePreviews.source))
    readonly property string key: inputsReady ? PresetModel.thumbKey(look, wallpaper, colors, Math.round(width) + "x" + Math.round(height)) : ""
    readonly property string file: key ? PresetStudio.thumbFile(key) : ""

    // "cache": showing the PNG; "queued"/"live": rendering; "done": the
    // live miniature stays on screen, its PNG serves the next visit.
    property string phase: "idle"
    property bool holdsSlot: false
    readonly property string uid: Math.random().toString(36).slice(2)
    readonly property bool shown: (phase === "cache" && cached.status === Image.Ready) || phase === "live" || phase === "done"

    Component.onCompleted: {
        SchemePreviews.refresh();
        keyUpdated();
    }
    Component.onDestruction: releaseSlot()
    onKeyChanged: keyUpdated()

    function keyUpdated() {
        releaseSlot();
        if (!key) {
            phase = "idle";
            return;
        }
        phase = PresetStudio.hasThumb(key) ? "cache" : "queued";
        tryRender();
    }

    function releaseSlot() {
        holdsSlot = false;
        PresetStudio.releaseRender(uid);
    }

    function tryRender() {
        if (phase !== "queued" || holdsSlot)
            return;
        if (!PresetStudio.acquireRender(uid))
            return;
        holdsSlot = true;
        phase = "live";
    }

    Connections {
        target: PresetStudio
        function onRenderingChanged() {
            root.tryRender();
        }
    }

    Image {
        id: cached
        anchors.fill: parent
        source: root.file && root.phase === "cache" ? "file://" + root.file : ""
        cache: true // file names are content hashes: never stale
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: root.phase === "cache"
        onStatusChanged: {
            // Indexed but unreadable (deleted meanwhile): render it again.
            if (status === Image.Error && root.phase === "cache") {
                root.phase = "queued";
                root.tryRender();
            }
        }
    }

    Loader {
        id: live
        anchors.fill: parent
        active: root.phase === "live" || root.phase === "done"
        sourceComponent: PresetMiniShell {
            look: root.look
            colorMap: root.colors
            wallpaper: root.wallpaper
            onReadyChanged: grabTimer.restart()
            Component.onCompleted: grabTimer.restart()
        }
    }

    // Let the miniature lay out and paint once before grabbing it.
    Timer {
        id: grabTimer
        interval: 120
        onTriggered: {
            const item = live.item;
            if (!item || !item.ready || root.phase !== "live")
                return;
            const target = root.file;
            item.grabToImage(result => {
                const saved = target === root.file && result.saveToFile(target);
                if (saved) {
                    PresetStudio.markRendered(root.key);
                    root.phase = "done";
                }
                root.releaseSlot();
            }, Qt.size(Math.round(root.width * 2), Math.round(root.height * 2)));
        }
    }

    // Skeleton
    Rectangle {
        id: skeleton
        anchors.fill: parent
        color: Colors.surfaceContainerHigh
        opacity: root.shown ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
            }
        }
        Rectangle {
            id: shine
            width: parent.width * 0.4
            height: parent.height
            x: -width
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Ui.alpha(Colors.overBackground, 0.08)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
            NumberAnimation on x {
                running: skeleton.visible && Config.animDuration > 0
                from: -shine.width
                to: skeleton.width
                duration: 1200
                loops: Animation.Infinite
            }
        }
    }
}
