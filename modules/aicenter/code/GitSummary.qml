pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Git state of the project in the ProjectBar (tasks.git): branch, ahead /
// behind, changed files. Click: a Commit popover (message typed by the
// user or written by the AI from the diff; `git add -A` + `git commit`).
StyledRect {
    id: root
    objectName: "gitSummary"

    property string dir: ""
    property string fallbackBranch: ""
    // Narrow bar: the branch icon and changed files only (the popover shows
    // the branch and ahead/behind).
    property bool compact: false
    readonly property var git: TasksService.gits[root.dir] || null
    readonly property string branch: root.git ? (root.git.detached ? (root.git.head || "").slice(0, 7) : root.git.branch || "") : root.fallbackBranch
    readonly property int changed: root.git ? root.git.changed || 0 : 0
    property string error: ""
    property bool writing: false

    function commit() {
        const msg = message.text.trim();
        if (!msg || committer.running)
            return;
        root.error = "";
        committer.command = ["sh", "-c", 'git -C "$1" add -A && git -C "$1" commit -q -m "$2"', "sh", root.dir, msg];
        committer.running = true;
    }
    function writeMessage() {
        if (differ.running)
            return;
        root.writing = true;
        root.error = "";
        differ.command = ["sh", "-c", 'git -C "$1" status --short; git -C "$1" diff HEAD | head -c 49152', "sh", root.dir];
        differ.running = true;
    }

    visible: root.branch.length > 0
    implicitWidth: row.implicitWidth + 14
    implicitHeight: 28
    radius: Styling.radius(-4)
    variant: hover.hovered || popup.opened ? "common" : "transparent"

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: {
            TasksService.refreshGit(root.dir);
            popup.open();
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 14)
        spacing: 5
        Text {
            text: Icons.gitBranch
            font.family: Icons.font
            font.pixelSize: BarLook.font(-2)
            color: Colors.outline
        }
        Text {
            objectName: "gitBranch"
            visible: !root.compact
            Layout.fillWidth: true
            Layout.maximumWidth: 160
            text: root.branch
            elide: Text.ElideMiddle
            font.family: Config.theme.monoFont
            font.pixelSize: BarLook.mono(-3)
            color: Colors.overSurface
        }
        Text {
            visible: !root.compact && !!root.git && (root.git.ahead > 0 || root.git.behind > 0)
            text: root.git ? (root.git.ahead > 0 ? "↑" + root.git.ahead : "") + (root.git.behind > 0 ? " ↓" + root.git.behind : "") : ""
            font.family: Config.theme.monoFont
            font.pixelSize: BarLook.mono(-4)
            color: Colors.outline
        }
        StyledRect {
            visible: root.changed > 0
            Layout.minimumWidth: implicitWidth
            implicitWidth: changedText.implicitWidth + 10
            implicitHeight: changedText.implicitHeight + 2
            radius: height / 2
            variant: "internalbg"
            Text {
                id: changedText
                objectName: "gitChanged"
                anchors.centerIn: parent
                text: "● " + root.changed
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                color: Colors.warning
            }
        }
    }

    Process {
        id: committer
        stderr: StdioCollector {
            id: commitErr
        }
        onExited: code => {
            if (code === 0) {
                message.text = "";
                popup.close();
            } else {
                root.error = commitErr.text.trim() || I18n.t("ai.git.commit_failed");
            }
            TasksService.refreshGit(root.dir);
        }
    }
    Process {
        id: differ
        stdout: StdioCollector {
            onStreamFinished: {
                const diff = text.trim();
                if (!diff) {
                    root.writing = false;
                    root.error = I18n.t("ai.git.nothing");
                    return;
                }
                Ai.runPrompt("Write a git commit message for the changes below: a summary line of at most 72 characters in the imperative mood, then (only if useful) a blank line and a short body. Reply with the message only, no code fences.\n\n" + diff, {
                    space: "code"
                }, (reply, err) => {
                    root.writing = false;
                    if (err)
                        root.error = err;
                    else
                        message.text = String(reply || "").replace(/^```\w*\n?|```$/g, "").trim();
                });
            }
        }
    }

    Popup {
        id: popup
        y: parent.height + 4
        // Inside the project bar: shifted left when it would overflow.
        width: Math.min(380, root.parent ? root.parent.width : 380)
        x: Math.max(-root.x, Math.min(0, (root.parent ? root.parent.width : 0) - root.x - width))
        padding: 10
        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(-2)
            enableShadow: true
        }
        contentItem: ColumnLayout {
            spacing: 8
            Text {
                objectName: "gitPopupBranch"
                Layout.fillWidth: true
                text: root.branch + (root.git && root.git.ahead > 0 ? "  ↑" + root.git.ahead : "") + (root.git && root.git.behind > 0 ? "  ↓" + root.git.behind : "")
                elide: Text.ElideMiddle
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.mono(-2)
                color: Colors.overSurface
            }
            Text {
                Layout.fillWidth: true
                text: root.git ? I18n.t("ai.git.summary").replace("%1", root.git.staged || 0).replace("%2", root.git.unstaged || 0).replace("%3", root.git.untracked || 0) + (root.git.conflicts > 0 ? " · " + I18n.t("ai.git.conflicts").replace("%1", root.git.conflicts) : "") : ""
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.outline
            }
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 96
                radius: Styling.radius(-4)
                variant: "common"
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    TextArea {
                        id: message
                        objectName: "commitInput"
                        placeholderText: I18n.t("ai.git.message_placeholder")
                        placeholderTextColor: Colors.outline
                        wrapMode: TextArea.Wrap
                        font.family: Config.theme.monoFont
                        font.pixelSize: BarLook.mono(-2)
                        color: Colors.overSurface
                        background: null
                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                root.commit();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.error.length > 0
                text: root.error
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.error
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Chip {
                    objectName: "commitWriteAi"
                    visible: Config.ai.tasks.commitWithAi
                    glyph: Icons.sparkle
                    label: root.writing ? I18n.t("ai.git.writing") : I18n.t("ai.git.write_ai")
                    enabled: !root.writing && root.changed > 0
                    variant: "transparent"
                    onClicked: root.writeMessage()
                }
                Item {
                    Layout.fillWidth: true
                }
                Chip {
                    objectName: "commitButton"
                    glyph: Icons.accept
                    label: I18n.t("ai.git.commit")
                    active: true
                    enabled: message.text.trim().length > 0 && root.changed > 0 && !committer.running
                    onClicked: root.commit()
                }
            }
        }
    }
}
