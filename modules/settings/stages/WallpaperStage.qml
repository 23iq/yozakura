pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Wallpaper: your screen with the wallpaper as it shows now (the
// bars, island and dock over it, no windows: the picture is the subject).
// Panorama mode draws the picture at the screen's height from its left
// edge (the first workspace, as PanoramaMath.layout does), and a scroll
// strip at the bottom shows the whole picture with the screen's slice
// bracketed. The arrows on the sides step through the library (the
// manager's previous / next wallpaper), a live change.
Stage {
    id: stage
    objectName: "wallpaperStage"

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var paths: stage.manager ? (stage.manager.wallpaperPaths || []) : []
    readonly property bool panorama: SettingsStore.get("desktop.wallpaperMode") === "panorama"
    // the picture's aspect (16:9 until it is known)
    readonly property real aspect: probe.implicitHeight > 0 ? probe.implicitWidth / probe.implicitHeight : 16 / 9
    // the part of the picture's width one screen shows in panorama mode
    readonly property real slice: Math.min(1, (stage.width / Math.max(1, stage.height)) / stage.aspect)

    stageHeight: Space.px(300)
    // Panorama: the picture at the screen's height, its left edge on screen.
    imageShift: Qt.point(stage.panorama ? Math.max(0, (stage.height * stage.aspect - stage.width) / 2) : 0, 0)

    Image {
        id: probe
        visible: false
        source: stage.wallpaper
        asynchronous: true
        sourceSize.height: Space.px(64)
    }

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showWindows: false

        // The whole picture as the panorama strip, the screen's slice ringed.
        Item {
            id: strip
            objectName: "wallpaperPanoramaStrip"
            readonly property real h: Math.round(mini.unit * 2.6)
            visible: opacity > 0
            opacity: stage.panorama ? 1 : 0
            width: Math.round(Math.min(mini.freeRect.w * 0.6, strip.h * stage.aspect))
            height: strip.h
            x: mini.freeRect.x + (mini.freeRect.w - width) / 2
            y: mini.freeRect.y + mini.freeRect.h - height - mini.unit * 0.6
            Behavior on opacity {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            Art {
                anchors.fill: parent
                source: stage.wallpaper
                radius: Look.radius("small", height)
            }
            Mark {
                anchors.fill: parent
                radius: Look.radius("small", height)
                color: Qt.alpha(Colors.shadow, 0.35)
            }
            Mark {
                width: Math.round(parent.width * stage.slice)
                height: parent.height
                radius: Look.radius("small", height)
                color: "transparent"
                border.width: Space.stroke
                border.color: Type.accent
            }
            StageSpot {
                keys: ["desktop.wallpaperMode"]
                cornerRadius: Look.radius("small", strip.h)
            }
        }

        // Previous / next wallpaper of the library.
        Repeater {
            model: [-1, 1]
            delegate: IconButton {
                id: step
                required property int modelData
                objectName: "wallpaperStep:" + (modelData < 0 ? "previous" : "next")
                visible: stage.paths.length > 1
                size: "m"
                icon: modelData < 0 ? Icons.caretLeft : Icons.caretRight
                tooltip: I18n.t(modelData < 0 ? "prefs.wall.previous" : "prefs.wall.next")
                x: modelData < 0 ? mini.freeRect.x + mini.unit * 0.6 : mini.freeRect.x + mini.freeRect.w - width - mini.unit * 0.6
                y: mini.freeRect.y + (mini.freeRect.h - height) / 2
                onClicked: {
                    if (!stage.manager)
                        return;
                    if (step.modelData < 0)
                        stage.manager.previousWallpaper();
                    else
                        stage.manager.nextWallpaper();
                }
            }
        }
    }
}
