pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common

// Top of the AI center: mode tabs, session/new/wide/pin/close buttons and the
// model (or agent) switcher chip.
ColumnLayout {
    id: root

    property bool historyOpen: false
    signal historyToggled
    signal pickModel

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        ModeTabs {
            mode: Ai.mode
            onSelected: m => Ai.setMode(m)
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
            glyph: GlobalStates.assistantWide ? Icons.arrowsInSimple : Icons.columns
            tooltip: I18n.t("ai.wide") + " (Ctrl+W)"
            active: GlobalStates.assistantWide
            onClicked: GlobalStates.assistantWide = !GlobalStates.assistantWide
        }
        IconButton {
            glyph: Icons.pin
            tooltip: I18n.t("ai.pin_sidebar")
            active: GlobalStates.assistantPinned
            onClicked: {
                GlobalStates.assistantPinned = !GlobalStates.assistantPinned;
                Config.ai.sidebarPinnedOnStartup = GlobalStates.assistantPinned;
            }
        }
        IconButton {
            glyph: Icons.cancel
            tooltip: I18n.t("ai.close") + " (Esc)"
            onClicked: GlobalStates.hideAssistant()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Chip {
            visible: Ai.mode !== "agent"
            image: Ai.currentModel ? Ai.currentModel.icon : ""
            glyph: Icons.sparkle
            label: Ai.currentModel ? Ai.currentModel.name : I18n.t("ai.choose_model")
            trailingIcon: Icons.caretUpDown
            maxLabelWidth: 240
            onClicked: root.pickModel()
        }
        Chip {
            visible: Ai.mode === "shell"
            glyph: Icons.plugsConnected
            label: "yozakura"
            mono: true
            variant: "common"
        }
        Chip {
            visible: Ai.mode === "chat" && Config.ai.chatTools && Ai.mcp !== null && Ai.mcp.allTools.length > 0
            glyph: Icons.plug
            label: I18n.t("ai.tools_count").replace("%1", Ai.mcp ? Ai.mcp.allTools.length : 0)
            onClicked: Config.ai.chatTools = !Config.ai.chatTools
        }
        Repeater {
            model: Ai.mode === "agent" && Ai.agents ? Ai.agents.agents.filter(a => a.available) : []
            delegate: Chip {
                id: entry
                required property var modelData
                glyph: Icons.robot
                label: entry.modelData.label
                active: Ai.agents.active ? Ai.agents.active.agent === entry.modelData.id : Config.ai.agents.defaultAgent === entry.modelData.id
                onClicked: {
                    Config.ai.agents.defaultAgent = entry.modelData.id;
                    if (Ai.agents.active && Ai.agents.active.agent !== entry.modelData.id)
                        Ai.agents.activeId = "";
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
