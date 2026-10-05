import QtQuick
import qs.modules.theme

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

    // One spacing unit for every panel: paddings and gaps derive from it
    readonly property real unit: Math.round(Styling.fontSize(-2) / 2)
    readonly property real padding: panel.unit * 3

    // Ask the view to close this panel (after an action that ends it)
    signal closeRequested
    // The user closed the panel while its content was still there (Esc,
    // click outside, another view taking over the notch)
    signal dismissed
}
