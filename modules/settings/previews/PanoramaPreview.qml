import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.globals
import qs.modules.components.kit
import qs.config
import qs.modules.settings.controls
import "../../desktop/panorama/PanoramaMath.js" as PanoramaMath

// Your current wallpaper laid out the way the mode shows it: the screen's
// frame on the whole image. Panorama: the frame glides from workspace to
// workspace (Motion.pan); fill: the centred crop.
PreviewStage {
    id: root

    property var entry
    readonly property bool panorama: (Config.desktop.wallpaperMode ?? "fill") === "panorama"
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string file: {
        const m = manager;
        if (!m)
            return "";
        const cur = m.currentWallpaper || "";
        if (cur && m.getFileType(cur) === "image")
            return cur;
        return (m.wallpaperPaths || []).find(p => m.getFileType(p) === "image") || "";
    }
    readonly property var screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080
    readonly property int slots: Math.max(2, Math.min(Config.workspaces.shown || 0, 5))
    property int slot: 0

    // The whole image, fitted into the stage.
    readonly property var geometry: PanoramaMath.layout(image.implicitWidth, image.implicitHeight, screenW, screenH)
    readonly property real fit: geometry.width > 0 ? Math.min((width - Space.l * 2) / geometry.width, (height - Space.l * 2) / screenH) : 0
    readonly property real frameX: panorama ? PanoramaMath.slotX(slot, slots, geometry.travel, screenW) : geometry.travel / 2

    stageHeight: Math.round(Math.min(width * 0.3, 190))

    Timer {
        interval: Math.max(Motion.pan.duration, 400) + 1100
        running: root.visible && root.panorama && root.geometry.travel > 0
        repeat: true
        onTriggered: root.slot = (root.slot + 1) % root.slots
    }

    Item {
        id: strip
        width: root.geometry.width * root.fit
        height: root.screenH * root.fit
        anchors.centerIn: parent

        Image {
            id: image
            width: parent.width
            height: root.geometry.height * root.fit
            y: root.geometry.y * root.fit
            source: root.file ? "file://" + root.file : ""
            sourceSize.width: PanoramaMath.MAX_TEXTURE
            sourceSize.height: 240
            asynchronous: true
            opacity: 0.45
        }

        // The screen's frame, at full brightness.
        Item {
            id: frame
            width: root.screenW * root.fit
            height: parent.height
            x: root.frameX * root.fit
            clip: true

            Behavior on x {
                enabled: Motion.pan.duration > 0
                NumberAnimation {
                    duration: Motion.pan.duration
                    easing.type: Motion.pan.easing
                }
            }

            Image {
                x: -frame.x
                y: image.y
                width: image.width
                height: image.height
                source: image.source
                sourceSize: image.sourceSize
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Space.hairline * 2
                border.color: Colors.primary
                radius: Look.chipRadius(Space.chip) / 2
            }
        }
    }
}
