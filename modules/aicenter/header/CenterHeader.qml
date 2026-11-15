pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.aicenter.common
import qs.modules.components.kit
import qs.config
import "../../components/preview/Preview.js" as Preview

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
    // a Settings picture (AiCenterPreview's PreviewContext): the space and
    // size are its samples ("ai.space", "ai.size"), never the live
    // assistant's, and no button acts; null live
    property var preview: null
    readonly property bool inPreview: Preview.on(root.preview)

    readonly property bool code: Preview.sample(root.preview, "ai.space", GlobalStates.aiSpace) === "code"
    readonly property string size: root.inPreview ? Preview.sample(root.preview, "ai.size", "compact") : (GlobalStates.assistantFullscreen ? "fullscreen" : (GlobalStates.assistantWide ? "wide" : "compact"))

    spacing: Space.xs / 2

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
        preview: root.preview
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
        onClicked: if (!root.inPreview)
            Ai.newConversation()
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
        onClicked: if (!root.inPreview)
            root.cycleSize()
    }
    IconButton {
        size: "xs"
        icon: Icons.cancel
        tooltip: I18n.t("ai.close") + " (Esc)"
        onClicked: if (!root.inPreview)
            GlobalStates.hideAssistant()
    }
}
