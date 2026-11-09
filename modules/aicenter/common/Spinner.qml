pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.config

// Small rotating activity indicator: a kit Icon in the progress ink.
Icon {
    id: root
    role: "caption"
    tone: "progress"

    property bool running: true

    icon: Icons.circleNotch
    visible: running

    RotationAnimator on rotation {
        running: root.running && root.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
