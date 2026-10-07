import QtQuick
import qs.modules.components.kit

// Base of every notch panel (registered in NotchPanels.js). The view sets
// the properties below; a panel sizes itself through implicitHeight and
// fills the width it is given.
Item {
    id: panel

    property string screenName: ""
    // False while the notch is hidden or covered (pause visualizers etc.)
    property bool revealed: true
    // Registry hint: list rows before scrolling (0 = panel default)
    property int maxRows: 0

    // Kit spacing: the small gap unit, the side / bottom inset (the
    // language's surface padding) and the smaller gap under the header
    readonly property real unit: Space.xs
    readonly property real padding: Look.surfacePadding
    readonly property real topPadding: Space.s

    // Ask the view to close this panel (after an action that ends it)
    signal closeRequested
    // The user closed the panel while its content was still there (Esc,
    // click outside, another view taking over the notch)
    signal dismissed
}
