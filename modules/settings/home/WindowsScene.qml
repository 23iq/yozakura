pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "SceneModel.js" as SceneModel

// Home tile scene of Windows: a small screen tiled the way your compositor
// tiles it (dwindle halves, a master and its stack, scrolling columns), with
// your gaps, border width and corner rounding to scale; the focused window
// wears the accent border.
Item {
    id: scene

    required property Card tile

    readonly property string layout: String(SettingsStore.get("compositor.layout") || "dwindle")
    readonly property real sh: screen.screenHeight
    readonly property int inner: SceneModel.scaled(SettingsStore.get("compositor.gapsIn") ?? 0, scene.sh)
    readonly property int outer: SceneModel.scaled(SettingsStore.get("compositor.gapsOut") ?? 0, scene.sh)
    readonly property int border: SceneModel.scaled(SettingsStore.get("compositor.borderSize") ?? 0, scene.sh)
    readonly property real rounding: SceneModel.scaled(SettingsStore.get("compositor.rounding") ?? 0, scene.sh)
    readonly property var rects: SceneModel.windows(scene.layout, screen.screenWidth, screen.screenHeight, scene.inner, scene.outer)

    SceneScreen {
        id: screen
        anchors.fill: parent

        Repeater {
            model: scene.rects
            delegate: Mark {
                id: win
                required property var modelData
                x: win.modelData.x
                y: win.modelData.y
                width: win.modelData.w
                height: win.modelData.h
                radius: Math.min(scene.rounding, Math.min(width, height) / 2)
                color: win.modelData.active ? Look.tonal(Type.accent) : Look.raisedFill(false)
                border.width: Math.max(Space.hairline, scene.border)
                border.color: win.modelData.active ? Type.accent : Type.track
                Behavior on color {
                    enabled: Motion.micro.duration > 0
                    ColorAnimation {
                        duration: Motion.micro.duration
                    }
                }

                // a title and a line of text in each window
                Column {
                    x: Math.max(Space.xs, win.radius * 0.6)
                    y: x
                    width: win.width - x * 2
                    spacing: Space.xs
                    visible: win.height > Space.l * 2
                    Mark {
                        width: parent.width * 0.6
                        height: Space.xs
                        color: win.modelData.active ? Type.accent : Type.track
                    }
                    Mark {
                        width: parent.width * 0.85
                        height: Space.xs
                        color: Type.track
                        visible: win.height > Space.l * 3
                    }
                }
            }
        }
    }
}
