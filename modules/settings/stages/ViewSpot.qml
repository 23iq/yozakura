import QtQuick
import qs.modules.settings.store
import qs.modules.settings.live

// A StageSpot over a part of a live hosted view (LiveHosted): the view's
// child named `name` (objectName), measured again when the view is built,
// moves or a setting changes (the view relays itself out). Hidden while
// that child is missing or not visible.
StageSpot {
    id: root

    required property LiveHosted hosted
    property string name: ""
    property rect at: Qt.rect(0, 0, 0, 0)

    function measure() {
        const it = root.hosted && root.hosted.ready ? root.hosted.find(root.name) : null;
        root.at = it && it.visible && it.width > 0 ? root.hosted.mapFromView(it) : Qt.rect(0, 0, 0, 0);
    }

    anchors.fill: undefined
    x: (root.hosted ? root.hosted.x + root.at.x : 0) - root.spread
    y: (root.hosted ? root.hosted.y + root.at.y : 0) - root.spread
    width: root.at.width + root.spread * 2
    height: root.at.height + root.spread * 2
    visible: root.opacity > 0 && root.at.width > 0

    Timer {
        id: later
        // after the view's own morphs (Motion.morph)
        interval: 450
        onTriggered: root.measure()
    }
    Connections {
        target: root.hosted
        function onReadyChanged() {
            later.restart();
        }
        function onZoomChanged() {
            later.restart();
        }
        function onWidthChanged() {
            later.restart();
        }
    }
    Connections {
        target: SettingsStore
        function onValueSet() {
            later.restart();
        }
    }
    Component.onCompleted: later.restart()
}
