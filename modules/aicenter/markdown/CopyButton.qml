pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.aicenter.common

// Copies `text` to the clipboard and flashes a check mark.
IconButton {
    id: root

    property string copyText: ""

    glyph: copied ? Icons.accept : Icons.copy
    tooltip: I18n.t("ai.copy")
    size: 24
    iconSize: 13
    property bool copied: false

    onClicked: {
        proc.command = ["wl-copy", "--", root.copyText];
        proc.running = true;
        copied = true;
        reset.restart();
    }

    Process {
        id: proc
    }
    Timer {
        id: reset
        interval: 1400
        onTriggered: root.copied = false
    }
}
