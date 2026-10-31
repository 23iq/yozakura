import QtQuick
import Quickshell
import qs.modules.components.kit

// The user's picture (~/.face.icon, then ~/.face) as a kit Avatar: the
// initials of `name` (the user name) when there is none.
Avatar {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property bool hasPicture: root.ready
    property int attempt: 0

    implicitWidth: Space.controlS
    implicitHeight: Space.controlS
    source: root.home === "" ? "" : "file://" + root.home + (root.attempt === 0 ? "/.face.icon" : "/.face")

    // Falls back to ~/.face when ~/.face.icon cannot be read.
    Image {
        visible: false
        source: root.attempt === 0 ? root.source : ""
        sourceSize: Qt.size(1, 1)
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Error)
                root.attempt = 1;
        }
    }
}
