pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components.surfaceeffects
import qs.modules.components.signatures

// Signature underlay (theme.signatures.brushHighlight): a faint sumi-e brush
// stroke, a little larger than the highlight it sits behind, so only its
// ragged ink edge shows around it. A Loader: nothing is created while the
// signature is off or the shell is quiet. Declare it inside the highlight
// item: `BrushHighlight { shown: <is highlighted> }`.
Loader {
    id: root

    property bool shown: true
    property real spread: 4
    property real strength: 0.3

    anchors.fill: parent
    anchors.margins: -spread
    z: -1
    active: Signatures.brush && shown

    sourceComponent: BrushStroke {
        color: Qt.alpha(Colors.primary, root.strength)
        seed: 1 + Math.random() * 40
        roughness: 0.8
        dryness: 0.6
    }
}
