pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Code space: project ▾ (recent folders, open folder…), git branch and the
// agent instructions file of the project the session works in.
RowLayout {
    id: root
    objectName: "projectBar"

    readonly property string home: Quickshell.env("HOME")
    readonly property string project: (Ai.agentSettings && Ai.agentSettings.cwd) || home
    readonly property var recents: (Config.ai.agents.recentDirs || []).filter(d => d !== project).slice(0, 6)
    readonly property bool locked: Ai.busy

    spacing: 6

    function shortPath(p) {
        return p && home && p.indexOf(home) === 0 ? "~" + p.substring(home.length) : (p || "");
    }
    function baseName(p) {
        return (p || "").split("/").filter(Boolean).pop() || "~";
    }
    // A different project starts a new session there.
    function choose(dir) {
        if (!dir || dir === project)
            return;
        if (Ai.activeAgent)
            Ai.newConversation();
        Ai.configureAgent({
            cwd: dir
        });
    }

    ProjectInfo {
        id: info
        dir: root.project
    }

    StyledRect {
        objectName: "projectButton"
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        implicitWidth: projectRow.implicitWidth + 16
        implicitHeight: 28
        radius: Styling.radius(-4)
        variant: projectHover.hovered || menu.visible ? "focus" : "common"
        opacity: root.locked ? 0.6 : 1
        HoverHandler {
            id: projectHover
            cursorShape: root.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
        TapHandler {
            enabled: !root.locked
            onTapped: menu.open()
        }
        RowLayout {
            id: projectRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 16)
            spacing: 6
            Text {
                text: Icons.folderOpen
                font.family: Icons.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.primary
            }
            Text {
                Layout.fillWidth: true
                text: root.baseName(root.project)
                elide: Text.ElideMiddle
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurface
            }
            Text {
                text: Icons.caretDown
                font.family: Icons.font
                font.pixelSize: BarLook.font(-5)
                color: Colors.outline
            }
        }

        Popup {
            id: menu
            y: parent.height + 4
            width: Math.max(260, parent.width)
            padding: 6
            background: StyledRect {
                variant: "popup"
                radius: Styling.radius(-2)
                enableShadow: true
            }
            contentItem: ColumnLayout {
                spacing: 2
                Text {
                    Layout.leftMargin: 8
                    Layout.topMargin: 2
                    text: root.shortPath(root.project)
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: menu.width - 24
                    font.family: Config.theme.monoFont
                    font.pixelSize: BarLook.mono(-3)
                    color: Colors.outline
                }
                Repeater {
                    model: root.recents
                    delegate: StyledRect {
                        id: recentItem
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Styling.radius(-6)
                        variant: itemHover.hovered ? "common" : "transparent"
                        HoverHandler {
                            id: itemHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                menu.close();
                                root.choose(recentItem.modelData);
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: Icons.folder
                                font.family: Icons.font
                                font.pixelSize: BarLook.font(-2)
                                color: Colors.outline
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.shortPath(recentItem.modelData)
                                elide: Text.ElideMiddle
                                font.family: Config.theme.font
                                font.pixelSize: BarLook.font(-2)
                                color: Colors.overSurface
                            }
                        }
                    }
                }
                Chip {
                    Layout.topMargin: 2
                    glyph: Icons.plus
                    label: I18n.t("ai.open_folder")
                    variant: "transparent"
                    onClicked: {
                        menu.close();
                        Ai.context.pickDirectory(root.project, dir => root.choose(dir));
                    }
                }
            }
        }
    }

    Chip {
        objectName: "projectBranch"
        visible: info.branch.length > 0
        glyph: Icons.gitBranch
        label: info.branch
        mono: true
        maxLabelWidth: 160
        variant: "transparent"
    }
    Chip {
        objectName: "projectInstructions"
        glyph: info.instructions ? Icons.fileText : Icons.warning
        label: info.instructions || I18n.t("ai.no_instructions")
        maxLabelWidth: 140
        variant: "transparent"
        opacity: info.instructions ? 1 : 0.7
        onClicked: if (info.instructions)
            Qt.openUrlExternally("file://" + root.project + "/" + info.instructions)
    }
    Item {
        Layout.fillWidth: true
    }
}
