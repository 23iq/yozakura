import QtQuick
import Quickshell.Io

// notifications.json of the Notifications service. Saves are coalesced
// (at most one write per `debounce` ms; the history can hold cached images)
// and written compact by `serialize`; a pending save is flushed when the
// service goes away. Nothing is written before the saved history was read
// (or found missing), so notifications that arrive during startup never
// overwrite it.
QtObject {
    id: file

    required property string path
    // () => string: the file content
    required property var serialize
    property int debounce: 500
    // The saved history was read (or there is none): writes may start
    property bool ready: false
    property bool _dirty: false

    // The file was read; text() holds it
    signal loaded
    // The file could not be read (missing on a first run or after the cache
    // was cleared, or unreadable): there is no saved history
    signal missing

    function text() {
        return file.view.text();
    }

    function reload() {
        file.view.reload();
    }

    function save() {
        file._dirty = true;
        if (file.ready)
            file.writeTimer.restart();
    }

    function flush() {
        file.writeTimer.stop();
        if (!file._dirty || !file.ready)
            return;
        file._dirty = false;
        file.view.setText(file.serialize());
    }

    function _setReady() {
        if (file.ready)
            return;
        file.ready = true;
        if (file._dirty)
            file.writeTimer.restart();
    }

    property FileView view: FileView {
        path: file.path
        onLoaded: {
            file.loaded();
            file._setReady();
        }
        onLoadFailed: {
            file.missing();
            file._setReady();
        }
    }

    property Timer writeTimer: Timer {
        interval: file.debounce
        repeat: false
        onTriggered: file.flush()
    }

    // Never block saving for good if the file view reports neither result
    property Timer readyFallback: Timer {
        interval: 5000
        running: true
        repeat: false
        onTriggered: file._setReady()
    }

    Component.onDestruction: {
        file.view.blockWrites = true;
        file.flush();
    }
}
