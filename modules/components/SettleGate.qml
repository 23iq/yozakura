import QtQuick

// Lets a value through only once it has stopped changing for `interval` ms.
//
// Used where a burst of changes would otherwise create and destroy native
// windows repeatedly (output hotplug churn, a preset applying several config
// flags at once): bind the window's Loader to `output` (or gate it on
// `settled`) instead of the raw value. QtWayland crashes when surfaces are
// created on, or moved between, outputs that are coming and going.
QtObject {
    id: gate

    // The raw, possibly bursty input.
    property var value
    // How long `value` must stay unchanged before it is let through.
    property int interval: 400
    // false: start unsettled and let the first value through only after
    // `interval` (an instance created in the middle of a burst).
    property bool startSettled: true

    // The last value that held still for `interval`.
    readonly property var output: _output
    // false from a change of `value` until it has held still for `interval`.
    readonly property bool settled: _settled

    property var _output
    property bool _settled: false

    onValueChanged: {
        _settled = false;
        _timer.restart();
    }

    Component.onCompleted: {
        if (startSettled) {
            _timer.stop();
            _output = value;
            _settled = true;
        } else {
            _timer.restart();
        }
    }

    property Timer _timer: Timer {
        interval: Math.max(1, gate.interval)
        onTriggered: {
            gate._output = gate.value;
            gate._settled = true;
        }
    }
}
