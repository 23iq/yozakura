pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config

// Small rotating activity indicator (icon font based, palette colored).
Text {
    id: root

    property bool running: true

    text: Icons.circleNotch
    font.family: Icons.font
    font.pixelSize: 14
    color: Colors.primary
    visible: running

    RotationAnimator on rotation {
        running: root.running && root.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
