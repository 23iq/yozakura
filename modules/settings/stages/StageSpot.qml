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
// A change of one of them flashes the part briefly too (the changed part
// of the preview), whichever control made it.
Mark {
    id: spot

    property var keys: []
    // Room around the part (px) and the corner radius of the ring.
    property real spread: Space.xs
    property real cornerRadius: Space.smallRadius
    function matches(f) {
        return spot.keys.some(k => f === k || f.startsWith(k + ".") || k.startsWith(f + "."));
    }
    // just changed (a short flash)
    property bool flashing: false
    readonly property bool lit: spot.flashing || (SettingsStore.focusKeys.length > 0 && SettingsStore.focusKeys.some(f => spot.matches(f)))
    Connections {
        target: SettingsStore
        function onValueSet(key, value) {
            if (spot.matches(String(key))) {
                spot.flashing = true;
                unflash.restart();
            }
        }
    }
    Timer {
        id: unflash
        interval: 700
        onTriggered: spot.flashing = false
    }

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
