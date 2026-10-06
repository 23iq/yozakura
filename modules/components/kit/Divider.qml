import QtQuick
import qs.modules.components.kit

// A hairline (overBackground at 8%), horizontal by default. Hidden in
// languages that separate by gaps only (Look.dividers: tiles).
Rectangle {
    id: root

    property bool vertical: false

    implicitWidth: root.vertical ? Space.hairline : 0
    implicitHeight: root.vertical ? 0 : Space.hairline
    color: Type.hairline
    visible: Look.dividers
}
