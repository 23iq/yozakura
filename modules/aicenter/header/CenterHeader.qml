pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.aicenter.common
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
        iconsOnly: root.width < 330
    }
    Item {
        Layout.fillWidth: true
    }
    IconButton {
        objectName: "headerUsage"
        visible: Config.ai.usage.headerButton !== false
        glyph: Icons.chartBar
        tooltip: I18n.t("ai.usage.title")
        active: root.usageOpen
        onClicked: root.usageToggled()
    }
    IconButton {
        objectName: "headerHistory"
        visible: !root.historyPinned
        glyph: Icons.clockCounterClockwise
        tooltip: I18n.t("ai.history") + " (Ctrl+H)"
        active: root.historyOpen
        onClicked: root.historyToggled()
    }
    IconButton {
        glyph: Icons.notePencil
        tooltip: (root.code ? I18n.t("ai.new_task") : I18n.t("ai.new_chat")) + " (Ctrl+N)"
        onClicked: Ai.newConversation()
    }
    IconButton {
        objectName: "headerChanges"
        visible: root.showChanges
        glyph: Icons.gitDiff
        tooltip: I18n.t("ai.changes")
        onClicked: root.changesToggled()
    }
    IconButton {
        objectName: "headerSettings"
        visible: root.code
        glyph: Icons.gear
        tooltip: I18n.t("ai.session_settings")
        active: root.settingsOpen
        onClicked: root.settingsToggled()
    }
    IconButton {
        objectName: "headerSize"
        glyph: root.size === "fullscreen" ? Icons.arrowsInSimple : Icons.arrowsOutSimple
        tooltip: I18n.t(root.size === "compact" ? "ai.wide" : (root.size === "wide" ? "ai.fullscreen" : "ai.compact")) + " (Ctrl+W)"
        onClicked: root.cycleSize()
    }
    IconButton {
        glyph: Icons.cancel
        tooltip: I18n.t("ai.close") + " (Esc)"
        onClicked: GlobalStates.hideAssistant()
    }
}
