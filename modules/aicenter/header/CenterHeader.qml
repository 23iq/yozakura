pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common

// A single engine choice and restrained workspace actions.
RowLayout {
    id: root
    property bool historyOpen: false
    signal historyToggled
    signal pickModel
    signal settingsToggled
    signal changesToggled
    spacing: 3

    Chip {
        image: Ai.currentModel ? Ai.currentModel.icon : ""
        glyph: Icons.sparkle
        label: Ai.currentModel ? Ai.currentModel.name : I18n.t("ai.choose_model")
        trailingIcon: Icons.caretUpDown
        maxLabelWidth: Math.max(65, Math.min(260, root.width - 250))
        variant: "transparent"
        onClicked: root.pickModel()
    }
    Item {
        Layout.fillWidth: true
    }
    IconButton {
        glyph: Icons.clockCounterClockwise
        tooltip: I18n.t("ai.history") + " (Ctrl+H)"
        active: root.historyOpen
        onClicked: root.historyToggled()
    }
    IconButton {
        glyph: Icons.notePencil
        tooltip: I18n.t("ai.new_chat") + " (Ctrl+N)"
        onClicked: Ai.newConversation()
    }
    IconButton {
        glyph: Icons.gear
        tooltip: I18n.t("ai.session_settings")
        onClicked: root.settingsToggled()
    }
    IconButton {
        glyph: Icons.gitDiff
        tooltip: I18n.t("ai.changes")
        visible: Ai.activeAgent !== null
        onClicked: root.changesToggled()
    }
    IconButton {
        glyph: GlobalStates.assistantFullscreen ? Icons.arrowsInSimple : Icons.arrowsOutSimple
        tooltip: I18n.t(GlobalStates.assistantWide ? "ai.fullscreen" : "ai.wide")
        onClicked: {
            if (GlobalStates.assistantFullscreen) {
                GlobalStates.assistantFullscreen = false;
                GlobalStates.assistantWide = false;
            } else if (GlobalStates.assistantWide) {
                GlobalStates.assistantFullscreen = true;
            } else {
                GlobalStates.assistantWide = true;
            }
        }
    }
    IconButton {
        glyph: Icons.cancel
        tooltip: I18n.t("ai.close") + " (Esc)"
        onClicked: GlobalStates.hideAssistant()
    }
}
