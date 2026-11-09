pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.aicenter.common
import qs.modules.components.kit
import qs.config

// [Assistant | Code] … usage, history, new, size, gear (Code), changes (Code), close.
// The engine chip lives in the composer strip (ComposerStatus).
RowLayout {
    id: root

    property bool historyOpen: false
    property bool historyPinned: false     // persistent history column shown
    property bool settingsOpen: false
    property bool showChanges: false
    property bool usageOpen: false
    signal usageToggled
    signal historyToggled
    signal settingsToggled
    signal changesToggled

    readonly property bool code: GlobalStates.aiSpace === "code"
    readonly property string size: GlobalStates.assistantFullscreen ? "fullscreen" : (GlobalStates.assistantWide ? "wide" : "compact")

    spacing: 2

    // compact -> wide -> fullscreen -> compact
    function cycleSize() {
        if (GlobalStates.assistantFullscreen) {
            GlobalStates.assistantFullscreen = false;
            GlobalStates.assistantWide = false;
        } else if (GlobalStates.assistantWide) {
            GlobalStates.assistantFullscreen = true;
        } else {
            GlobalStates.assistantWide = true;
        }
    }

    SpaceSwitch {
        iconsOnly: root.width < (root.code ? 400 : 330)
    }
    Item {
        Layout.fillWidth: true
    }
    IconButton {
        size: "xs"
        objectName: "headerUsage"
        visible: Config.ai.usage.headerButton !== false
        icon: Icons.chartBar
        tooltip: I18n.t("ai.usage.title")
        active: root.usageOpen
        onClicked: root.usageToggled()
    }
    IconButton {
        size: "xs"
        objectName: "headerHistory"
        visible: !root.historyPinned
        icon: Icons.clockCounterClockwise
        tooltip: I18n.t("ai.history") + " (Ctrl+H)"
        active: root.historyOpen
        onClicked: root.historyToggled()
    }
    IconButton {
        size: "xs"
        icon: Icons.notePencil
        tooltip: (root.code ? I18n.t("ai.new_task") : I18n.t("ai.new_chat")) + " (Ctrl+N)"
        onClicked: Ai.newConversation()
    }
    IconButton {
        size: "xs"
        objectName: "headerChanges"
        visible: root.showChanges
        icon: Icons.gitDiff
        tooltip: I18n.t("ai.changes")
        onClicked: root.changesToggled()
    }
    IconButton {
        size: "xs"
        objectName: "headerSettings"
        visible: root.code
        icon: Icons.gear
        tooltip: I18n.t("ai.session_settings")
        active: root.settingsOpen
        onClicked: root.settingsToggled()
    }
    IconButton {
        size: "xs"
        objectName: "headerSize"
        icon: root.size === "fullscreen" ? Icons.arrowsInSimple : Icons.arrowsOutSimple
        tooltip: I18n.t(root.size === "compact" ? "ai.wide" : (root.size === "wide" ? "ai.fullscreen" : "ai.compact")) + " (Ctrl+W)"
        onClicked: root.cycleSize()
    }
    IconButton {
        size: "xs"
        icon: Icons.cancel
        tooltip: I18n.t("ai.close") + " (Esc)"
        onClicked: GlobalStates.hideAssistant()
    }
}
