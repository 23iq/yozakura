import QtQuick
import qs.modules.theme

// A user of the shared weather clock (WeatherFx.frame, ~10 Hz): while
// `ticking` it keeps the clock running and emits `tick(now)` once per frame.
// Nothing else wakes the shell, so a tween stepped here costs one frame per
// tick however many effects move.
Item {
    id: root

    property bool ticking: false
    signal tick(real now)

    visible: false

    onTickingChanged: WeatherFx.tickUsers += root.ticking ? 1 : -1
    Component.onDestruction: {
        if (root.ticking)
            WeatherFx.tickUsers -= 1;
    }
    Connections {
        target: WeatherFx.frame
        enabled: root.ticking
        function onTriggered(): void {
            root.tick(Date.now());
        }
    }
}
