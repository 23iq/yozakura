pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit

// MCP servers: the built-in yozakura server plus servers imported from
// Claude Code, Codex and OpenCode. Enable/disable each, inspect its tools.
ColumnLayout {
    id: root

    property var entry

    spacing: Space.m

    property string expanded: ""
    property var tools: []
    property string toolsError: ""

    function toggleTools(name) {
        if (expanded === name) {
            expanded = "";
            return;
        }
        expanded = name;
        tools = [];
        toolsError = "";
        Ai.mcp.serverTools(name, (list, err) => {
            tools = list;
            toolsError = err;
        });
    }

    Repeater {
        model: Ai.mcp ? Ai.mcp.servers : []
        delegate: StyledRect {
            id: row
            required property var modelData
            readonly property bool on: Ai.mcp.isEnabled(row.modelData.name)
            Layout.fillWidth: true
            variant: "common"
            radius: Look.radius("control")
            implicitHeight: srvCol.implicitHeight + 16

            ColumnLayout {
                id: srvCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.s
                spacing: Space.s

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Space.s
                    Icon {
                        role: "caption"
                        icon: row.modelData.transport === "stdio" ? Icons.terminal : Icons.globe
                        color: row.on ? Colors.primary : Colors.outline
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        KitText {
                            role: "secondary"
                            text: row.modelData.name
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-1)
                            color: Colors.overSurface
                        }
                        KitText {
                            role: "caption"
                            Layout.fillWidth: true
                            text: row.modelData.source + " · " + (row.modelData.url || ((row.modelData.command || "") + " " + (row.modelData.args || []).join(" ")))
                            elide: Text.ElideMiddle
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-4)
                        }
                    }
                    Chip {
                        icon: Icons.wrench
                        text: I18n.t("ai.view_tools")
                        active: root.expanded === row.modelData.name
                        onClicked: root.toggleTools(row.modelData.name)
                    }
                    AiToggleRow {
                        Layout.fillWidth: false
                        checked: row.on
                        onToggled: v => Ai.mcp.setEnabled(row.modelData.name, v)
                    }
                }

                Repeater {
                    model: root.expanded === row.modelData.name ? root.tools : []
                    delegate: RowLayout {
                        id: entry1
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: Space.xl
                        spacing: Space.s
                        Icon {
                            role: "label"
                            tone: "muted"
                            icon: entry1.modelData.annotations && entry1.modelData.annotations.readOnlyHint ? Icons.eye : Icons.pencil
                        }
                        KitText {
                            role: "caption"
                            text: entry1.modelData.name
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-3)
                            color: Colors.overSurface
                        }
                        KitText {
                            role: "caption"
                            Layout.fillWidth: true
                            text: (entry1.modelData.description || "").split("\n")[0]
                            elide: Text.ElideRight
                        }
                    }
                }
                KitText {
                    role: "caption"
                    visible: root.expanded === row.modelData.name && (root.toolsError.length > 0 || root.tools.length === 0)
                    Layout.leftMargin: Space.xl
                    text: root.toolsError || I18n.t("ai.loading")
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    color: root.toolsError ? Colors.error : Colors.outline
                }
            }
        }
    }

    Component.onCompleted: {
        Ai._ensureInit();
        if (Ai.mcp)
            Ai.mcp.refresh();
    }
}
