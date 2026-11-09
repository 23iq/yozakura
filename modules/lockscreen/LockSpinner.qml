import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../components/kit/ProgressMotion.js" as ProgressMotion

// The submit glyph of a password field: `idleIcon` (an arrow) at rest, a
// calm spinning notch while `busy` (PAM is checking). One turn takes the
// kit's indeterminate progress cycle; still when motion is off.
Icon {
    id: root

    property bool busy: false
    property string idleIcon: Icons.arrowRight
    readonly property int cycle: ProgressMotion.cycle(Motion.emphasis.duration)

    icon: root.busy ? Icons.circleNotch : root.idleIcon
    role: "secondary"

    RotationAnimator on rotation {
        running: root.busy && root.cycle > 0
        from: 0
        to: 360
        duration: Math.max(1, root.cycle)
        loops: Animation.Infinite
    }

    onBusyChanged: if (!root.busy)
        rotation = 0
}
