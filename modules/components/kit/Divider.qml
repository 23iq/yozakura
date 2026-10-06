import QtQuick

// A hairline (overBackground at 8%), horizontal by default.
Rectangle {
    id: root

    property bool vertical: false

    implicitWidth: root.vertical ? Space.hairline : 0
    implicitHeight: root.vertical ? 0 : Space.hairline
    color: Type.hairline
}
