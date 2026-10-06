import QtQuick
import qs.modules.terminal

// Settings > Terminal & Apps > Terminal look: the live kitty preview,
// status notices and prompt gallery (modules/terminal, shared with
// onboarding).
Item {
    id: root

    property var entry

    implicitHeight: section.implicitHeight

    TerminalLookSection {
        id: section
        width: root.width
    }
}
