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

// Code space: project ▾ (recent folders, "Open folder…" = pickRequested,
// the in-bar FolderPicker), git summary with
// Commit (GitSummary), the agent instructions file (missing: "Create with
// agent" starts an `instructions` template task) and the project's task
// settings (ProjectSettings).
RowLayout {
    id: root
    objectName: "projectBar"

    readonly property string home: Quickshell.env("HOME")
    readonly property string project: (Ai.agentSettings && Ai.agentSettings.cwd) || Ai.projectDir || home
    readonly property var recents: (Config.ai.agents.recentDirs || []).filter(d => d !== project).slice(0, 6)
    signal pickRequested
    readonly property bool narrow: width < 420

    spacing: 6

    function shortPath(p) {
        return p && home && p.indexOf(home) === 0 ? "~" + p.substring(home.length) : (p || "");
    }
    function baseName(p) {
        return (p || "").split("/").filter(Boolean).pop() || "~";
    }
    // A different project: its board, or a new session there (Ai.chooseProject).
    function choose(dir) {
        if (dir)
            Ai.chooseProject(dir);
    }

    ProjectInfo {
        id: info
        dir: root.project
    }
    onProjectChanged: TasksService.refreshAll(root.project)
    Component.onCompleted: TasksService.refreshAll(root.project)

    readonly property string instructions: (TasksService.projects[root.project] ? TasksService.projects[root.project].instructions : "") || info.instructions
    property string createError: ""
    function createInstructions() {
        const agents = (Config.ai.tasks.defaultAgents || []).filter(Boolean);
        TasksService.create({
            "dir": root.project,
            "template": "instructions",
            "prompt": "",
            "agent": agents[0] || Config.ai.agents.defaultAgent || "claude"
        }, (task, error) => root.createError = error || "");
    }

    StyledRect {
        objectName: "projectButton"
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        Layout.minimumWidth: Math.min(implicitWidth, 120)
        implicitWidth: projectRow.implicitWidth + 16
        implicitHeight: 28
        radius: Styling.radius(-4)
        variant: projectHover.hovered || menu.visible ? "focus" : "common"
        HoverHandler {
            id: projectHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.recents.length > 0 ? menu.open() : root.pickRequested()
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
            width: Math.min(Math.max(260, parent.width), root.width)
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
                    objectName: "projectOpenFolder"
                    Layout.topMargin: 2
                    glyph: Icons.plus
                    label: I18n.t("ai.open_folder")
                    variant: "transparent"
                    onClicked: {
                        menu.close();
                        root.pickRequested();
                    }
                }
            }
        }
    }

    // Branch and instructions shrink (elide) before the project name.
    GitSummary {
        objectName: "projectBranch"
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        Layout.minimumWidth: Math.min(implicitWidth, 84)
        compact: root.narrow
        dir: root.project
        fallbackBranch: info.branch
    }
    Chip {
        objectName: "projectInstructions"
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        Layout.minimumWidth: 34
        glyph: root.instructions ? Icons.fileText : Icons.warning
        label: root.narrow ? "" : (root.instructions || I18n.t("ai.no_instructions"))
        maxLabelWidth: 140
        variant: "transparent"
        opacity: root.instructions ? 1 : 0.7
        onClicked: {
            if (root.instructions)
                Qt.openUrlExternally("file://" + root.project + "/" + root.instructions);
            else
                instructionsMenu.open();
        }
        Popup {
            id: instructionsMenu
            y: parent.height + 4
            x: Math.min(0, root.width - parent.x - width)
            width: Math.min(300, root.width)
            padding: 10
            background: StyledRect {
                variant: "popup"
                radius: Styling.radius(-2)
                enableShadow: true
            }
            contentItem: ColumnLayout {
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.instructions_missing")
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.overSurface
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.createError.length > 0
                    text: root.createError
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    color: Colors.error
                }
                Chip {
                    objectName: "createInstructions"
                    glyph: Icons.sparkle
                    label: I18n.t("ai.tasks.create_instructions")
                    active: true
                    onClicked: {
                        instructionsMenu.close();
                        root.createInstructions();
                    }
                }
            }
        }
    }
    Item {
        Layout.fillWidth: true
    }
    ProjectSettings {
        dir: root.project
    }
}
