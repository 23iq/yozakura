import QtQuick
import qs.modules.terminal

// Settings > Terminal > When a terminal opens: the fastfetch greeting
// (switch, live preview, look, logo; modules/terminal/FastfetchSection).
Item {
    id: root

    property var entry

    implicitHeight: section.implicitHeight

    FastfetchSection {
        id: section
        width: root.width
    }
}
