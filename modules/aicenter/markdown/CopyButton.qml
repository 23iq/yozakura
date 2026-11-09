pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.aicenter.common
import qs.modules.components.kit

// Copies `text` to the clipboard and flashes a check mark.
IconButton {
    id: root

    property string copyText: ""

    icon: copied ? Icons.accept : Icons.copy
    tooltip: I18n.t("ai.copy")
    size: "xs"
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
