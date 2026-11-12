import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store

// A part of a stage that the settings `keys` change: while a row editing
// one of them is under the pointer or keyboard focus
// (SettingsStore.focusKeys), the part is ringed in the accent with a soft
// wash, so the user sees what that row is about. Declare it inside the
// part: `StageSpot { keys: ["bar.position"] }`. Keys match by prefix both
// ways (bar.layout matches bar.layout.left and the other way round).
Mark {
    id: spot

    property var keys: []
    // Room around the part (px) and the corner radius of the ring.
    property real spread: Space.xs
    property real cornerRadius: Space.smallRadius
    readonly property bool lit: SettingsStore.focusKeys.length > 0 && spot.keys.some(k => SettingsStore.focusKeys.some(f => f === k || f.startsWith(k + ".") || k.startsWith(f + ".")))

    anchors.fill: parent
    anchors.margins: -spot.spread
    z: 50
    radius: spot.cornerRadius + spot.spread
    color: Qt.alpha(Type.accent, 0.12)
    border.width: Space.stroke - 1
    border.color: Type.accent
    opacity: spot.lit ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }
}
