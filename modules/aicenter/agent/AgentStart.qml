pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Agent mode without an open session: pick the CLI agent and project folder;
// the first message from the composer starts the session.
ColumnLayout {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property var agents: Ai.agents ? Ai.agents.agents : []
    readonly property string cwd: Config.ai.agents.defaultCwd || home

    spacing: 14

    function shortPath(p) {
        return p && p.indexOf(home) === 0 ? "~" + p.substring(home.length) : p;
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Icons.terminalWindow
        font.family: Icons.font
        font.pixelSize: 34
        color: Colors.primary
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: I18n.t("ai.agent_title")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(8)
        font.weight: Font.Bold
        color: Colors.overBackground
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.width - 32
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("ai.agent_hint")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.outline
    }

    Text {
        Layout.leftMargin: 16
        Layout.topMargin: 6
        text: I18n.t("ai.agent_pick")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Colors.outline
    }
    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 8
        Repeater {
            model: root.agents
            delegate: Chip {
                id: entry0
                required property var modelData
                glyph: entry0.modelData.available ? Icons.robot : Icons.warning
                label: entry0.modelData.label + (entry0.modelData.available ? "" : " · " + I18n.t("ai.not_installed"))
                active: Config.ai.agents.defaultAgent === entry0.modelData.id
                enabled: entry0.modelData.available
                opacity: enabled ? 1 : 0.55
                onClicked: Config.ai.agents.defaultAgent = entry0.modelData.id
            }
        }
        Text {
            visible: root.agents.length === 0
            text: BackendService.socketAvailable ? I18n.t("ai.agents_loading") : I18n.t("ai.backend_offline")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }

    Text {
        Layout.leftMargin: 16
        Layout.topMargin: 6
        text: I18n.t("ai.agent_folder")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Colors.outline
    }
    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 8
        Chip {
            glyph: Icons.folderOpen
            label: root.shortPath(root.cwd)
            mono: true
            active: true
            maxLabelWidth: 260
        }
        Repeater {
            model: (Config.ai.agents.recentDirs || []).filter(d => d !== root.cwd).slice(0, 5)
            delegate: Chip {
                id: entry1
                required property var modelData
                glyph: Icons.folder
                label: root.shortPath(entry1.modelData)
                mono: true
                maxLabelWidth: 200
                onClicked: Config.ai.agents.defaultCwd = entry1.modelData
            }
        }
        Chip {
            glyph: Icons.plus
            label: I18n.t("ai.browse")
            onClicked: Ai.context.pickDirectory(root.cwd, dir => {
                if (dir)
                    Config.ai.agents.defaultCwd = dir;
            })
        }
    }
}
