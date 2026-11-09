import QtQuick
import "SurfaceInput.js" as SurfaceInput

// Map/unmap latch for a layer window that animates out before it hides.
//
// Binding `visible: open || anim.running` can go false and true again in one
// tick (the binding re-evaluates between the open flag and the animation
// start), unmapping and remapping the surface while keyboard focus flips and
// a text field still holds text-input-v3: QtWayland crashes on that. The
// latch orders the close instead:
//   1. the input method is committed and focus leaves the item holding it
//      (the active focus item of `focusHost`'s window), then
//      `releaseFocus()` fires,
//   2. `keyboard` goes false (bind the window's keyboardFocus to it),
//   3. `shown` (bind the window's visible to it) goes false only after
//      `holdMs` plus at least one frame, so the unmap never shares a tick
//      with the focus change, also when animations are 0 ms.
// Re-opening before that keeps the surface mapped.
QtObject {
    id: latch

    // The panel wants to be open.
    property bool active: false
    // Length of the close animation (ms); 0 when animations are off.
    property int holdMs: 0
    // One frame at 60 Hz: the minimum time between focus drop and unmap.
    readonly property int frameMs: 17
    // Any item in the window: its window's focused field lets go on close.
    property Item focusHost: null

    readonly property bool shown: _shown
    readonly property bool keyboard: _keyboard

    signal releaseFocus

    property bool _shown: false
    property bool _keyboard: false

    function sync(): void {
        if (active) {
            _hide.stop();
            _shown = true;
            _keyboard = true;
        } else if (_shown) {
            if (_keyboard) {
                SurfaceInput.release(Qt.inputMethod, focusHost ? focusHost.Window.activeFocusItem : null);
                releaseFocus();
                _keyboard = false;
            }
            _hide.interval = Math.max(0, holdMs) + frameMs;
            _hide.restart();
        }
    }

    onActiveChanged: sync()
    Component.onCompleted: sync()

    property Timer _hide: Timer {
        onTriggered: {
            if (!latch.active)
                latch._shown = false;
        }
    }
}
