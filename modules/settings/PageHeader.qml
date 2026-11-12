import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit

// The action row of a hand-written page (Save current look, Add...): the
// title, tabs and "Reset page" are drawn once by the window
// (DestinationHeader), so this shows only its children, flush right, and
// takes no room without them. `category` / `description` are accepted for
// the pages that still pass them; nothing prints them.
RowLayout {
    id: header

    property var category: null
    property string description: ""

    spacing: Space.l
    visible: header.children.length > 1
    height: visible ? implicitHeight : 0

    Item {
        Layout.fillWidth: true
    }
}
