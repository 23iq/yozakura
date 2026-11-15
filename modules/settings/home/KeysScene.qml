pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "SceneModel.js" as SceneModel

// Home tile scene of Keyboard: a corner of your keyboard, the first keys of
// two rows (the second one staggered) printed in your first layout, with
// the second layout's letters in the lower corner of each cap like a
// bilingual keyboard (SceneModel.keyRows: QWERTY, QWERTZ, AZERTY, Cyrillic,
// ...). The home key wears its bump.
Item {
    id: scene

    required property Card tile

    readonly property var layouts: SettingsStore.get("keyboard.layouts") || []
    readonly property bool twoRows: (scene.height - Space.xs) / 2 >= Space.px(28)
    readonly property real gap: Space.xs
    // keys as tall as the room holds (three at least), as many a row as fit
    // beside the home row's stagger
    readonly property real cap: Math.floor(Math.min(Space.controlS, scene.twoRows ? (scene.height - scene.gap) / 2 : scene.height, (scene.width - scene.gap * 2) / 3))
    readonly property real stagger: scene.twoRows ? Math.round(scene.cap * 0.4) : 0
    readonly property int count: Math.max(2, Math.min(6, Math.floor((scene.width - scene.stagger + scene.gap) / (scene.cap + scene.gap))))
    readonly property var primary: SceneModel.keyRows(scene.layouts[0] || "us", scene.count)
    readonly property var second: scene.layouts.length > 1 ? SceneModel.keyRows(scene.layouts[1], scene.count) : null

    Column {
        anchors.centerIn: parent
        spacing: scene.gap
        Repeater {
            model: scene.twoRows ? 2 : 1
            delegate: Row {
                id: keyRow
                required property int index
                // the home row sits half a key to the right
                leftPadding: keyRow.index === 1 ? scene.stagger : 0
                spacing: scene.gap
                Repeater {
                    model: scene.primary[keyRow.index]
                    delegate: Mark {
                        id: key
                        required property string modelData
                        required property int index
                        readonly property bool home: keyRow.index === 1 && key.index === 3
                        width: scene.cap
                        height: scene.cap
                        radius: Look.radius("control", height * 0.7)
                        color: Look.raisedFill(false)
                        border.width: Space.hairline
                        border.color: Look.boxedControls && Look.controlEdge.a > 0 ? Look.controlEdge : Type.track

                        KitText {
                            x: Math.round(key.width * 0.16)
                            y: Math.round(key.height * 0.08)
                            role: scene.cap >= Space.px(30) ? "body" : "caption"
                            font.weight: Font.Medium
                            text: key.modelData
                        }
                        KitText {
                            visible: scene.second !== null && scene.cap >= Space.px(26)
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: Math.round(key.width * 0.14)
                            anchors.bottomMargin: Math.round(key.height * 0.04)
                            role: "caption"
                            color: Type.muted
                            text: scene.second ? scene.second[keyRow.index][key.index] || "" : ""
                        }
                        // the home key's bump
                        Mark {
                            visible: key.home
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.round(key.height * 0.14)
                            width: Math.round(key.width * 0.26)
                            height: Math.max(Space.hairline * 2, Math.round(key.height * 0.05))
                            color: scene.tile.hovered ? Type.accent : Type.muted
                        }
                    }
                }
            }
        }
    }
}
