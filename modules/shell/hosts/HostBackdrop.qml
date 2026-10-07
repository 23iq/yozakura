import QtQuick
import qs.config
import qs.modules.theme

// Click-outside area behind a host's frame. With layout.backdrop on it also
// paints the dimming scrim (the compositor blurs the layer behind it); off,
// nothing is drawn, so nothing is dimmed or blurred, and a click still closes.
Item {
    id: root

    // Scrim opacity at full progress, and the host's open progress (0..1).
    property real strength: 0.5
    property real progress: 0

    readonly property bool shown: Config.layout ? Config.layout.backdrop === true : false

    signal clicked

    Rectangle {
        anchors.fill: parent
        visible: root.shown
        color: Colors.scrim
        opacity: root.strength * Math.min(1, root.progress)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.clicked()
    }
}
