pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import "../../services/tasks/TaskModel.js" as TaskModel

// Review of a finished run: the agent's summary, the check result, the
// commit message (editable, the agent's proposal) and the changes; Accept
// (squash/merge into the current branch), Request changes (a follow-up
// for the agent) or Discard. Best-of-N shows the runs side by side first.
ColumnLayout {
    id: root
    objectName: "reviewView"

    property var task: null
    property int run: 0
    property string error: ""
    property bool busy: false
    signal runChosen(int index)

    readonly property var cfg: Config.ai.tasks
    readonly property var current: TaskModel.runAt(root.task, root.run)
    readonly property var check: TaskModel.lastCheck(root.current)
    readonly property var acts: TaskModel.actions(root.task)
    readonly property bool reviewable: !!root.current && root.current.status === "review"

    function finish(res, error) {
        root.busy = false;
        root.error = error || "";
    }
    function accept() {
        if (!root.reviewable)
            return;
        if (root.cfg.confirmAccept)
            confirmAccept.ask();
        else
            root.doAccept();
    }
    function doAccept() {
        root.busy = true;
        root.error = "";
        TasksService.accept(root.task.id, root.run, message.text.trim(), (r, e) => root.finish(r, e));
    }
    function requestChanges() {
        changesField.forceActiveFocus();
    }
    function sendChanges() {
        const text = changesField.text.trim();
        if (!text || !root.acts.followup)
            return;
        root.busy = true;
        TasksService.followup(root.task.id, root.run, text, (r, e) => {
            root.finish(r, e);
            if (!e)
                changesField.text = "";
        });
    }
    function discard() {
        if (root.cfg.confirmDiscard)
            confirmDiscard.ask();
        else
            root.doDiscard();
    }
    function doDiscard() {
        root.busy = true;
        TasksService.discard(root.task.id, (root.task.runs || []).length > 1 ? root.run : -1, (r, e) => root.finish(r, e));
    }

    // Keep the message the user typed while the same run stays selected.
    property string _messageFor: ""
    function loadMessage() {
        const key = root.task ? root.task.id + ":" + root.run : "";
        if (key === root._messageFor)
            return;
        root._messageFor = key;
        message.text = TaskModel.commitMessage(root.task, root.current);
        root.error = "";
    }
    onCurrentChanged: loadMessage()
    Component.onCompleted: loadMessage()

    spacing: BarLook.gap

    RunChoice {
        Layout.fillWidth: true
        visible: root.task && (root.task.runs || []).length > 1
        task: root.task
        run: root.run
        onChosen: index => root.runChosen(index)
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(top.implicitHeight, root.height * 0.55)
        clip: true
        contentHeight: top.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: top
            width: parent.width
            spacing: BarLook.gap

            RowLayout {
                Layout.fillWidth: true
                visible: root.check !== null
                spacing: 6
                Glyph {
                    text: root.check && root.check.status === "pass" ? Icons.checkCircle : Icons.xCircle
                    role: root.check && root.check.status === "pass" ? "success" : "error"
                }
                UiText {
                    Layout.fillWidth: true
                    text: root.check ? I18n.t("ai.tasks.check_line").replace("%1", root.check.command || "").replace("%2", I18n.t("ai.tasks.check." + root.check.status)).replace("%3", root.current.attempts || 0) : ""
                    size: -2
                }
            }

            MarkdownView {
                Layout.fillWidth: true
                visible: !!root.current && !!root.current.summary
                text: root.current ? root.current.summary || "" : ""
                fontSize: BarLook.font(-1)
            }

            UiText {
                Layout.fillWidth: true
                visible: !!root.current && !!root.current.error
                text: root.current ? root.current.error || "" : ""
                color: Colors.error
                wrapMode: Text.Wrap
                size: -2
            }

            UiText {
                text: I18n.t("ai.tasks.commit_message")
                muted: true
                size: -3
                visible: root.reviewable
            }
            StyledRect {
                Layout.fillWidth: true
                visible: root.reviewable
                implicitHeight: Math.min(140, message.implicitHeight + 8)
                radius: Styling.radius(-4)
                variant: "common"
                border.width: message.activeFocus ? 1 : 0
                border.color: Colors.primary
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    TextArea {
                        id: message
                        objectName: "commitMessage"
                        wrapMode: TextArea.Wrap
                        font.family: Config.theme.monoFont
                        font.pixelSize: BarLook.mono(-2)
                        color: Colors.overSurface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.overPrimary
                        background: null
                    }
                }
            }

            StyledRect {
                objectName: "reviewError"
                Layout.fillWidth: true
                visible: root.error.length > 0
                implicitHeight: errorText.implicitHeight + 14
                radius: Styling.radius(-4)
                variant: "error"
                RowLayout {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 8
                    Glyph {
                        text: Icons.warning
                        color: Styling.srItem("error")
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: I18n.t("ai.tasks.action_failed").replace("%1", root.error)
                        wrapMode: Text.Wrap
                        size: -2
                        color: Styling.srItem("error")
                    }
                }
            }

            ConfirmStrip {
                id: confirmAccept
                objectName: "confirmAccept"
                Layout.fillWidth: true
                text: I18n.t("ai.tasks.confirm_accept").replace("%1", root.task ? root.task.baseBranch || "HEAD" : "")
                confirmLabel: I18n.t("ai.tasks.accept")
                onConfirmed: root.doAccept()
            }
            ConfirmStrip {
                id: confirmDiscard
                objectName: "confirmDiscard"
                Layout.fillWidth: true
                danger: true
                text: I18n.t("ai.tasks.confirm_discard")
                confirmLabel: I18n.t("ai.tasks.discard")
                onConfirmed: root.doDiscard()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    id: changesField
                    objectName: "requestChanges"
                    Layout.fillWidth: true
                    enabled: root.acts.followup
                    placeholderText: I18n.t("ai.tasks.request_placeholder")
                    placeholderTextColor: Colors.outline
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-1)
                    background: StyledRect {
                        variant: "common"
                        radius: Styling.radius(-4)
                    }
                    onAccepted: root.sendChanges()
                    Keys.onEscapePressed: {
                        text = "";
                        focus = false;
                    }
                }
                Chip {
                    objectName: "requestChangesSend"
                    visible: changesField.text.trim().length > 0
                    glyph: Icons.paperPlaneRight
                    label: I18n.t("ai.tasks.request_changes")
                    onClicked: root.sendChanges()
                }
                Chip {
                    objectName: "reviewDiscard"
                    visible: root.acts.discard
                    glyph: Icons.trash
                    label: I18n.t("ai.tasks.discard")
                    variant: "transparent"
                    enabled: !root.busy
                    onClicked: root.discard()
                }
                Chip {
                    objectName: "reviewAccept"
                    visible: root.reviewable
                    glyph: Icons.accept
                    label: I18n.t("ai.tasks.accept")
                    active: true
                    enabled: !root.busy
                    onClicked: root.accept()
                }
            }
        }
    }

    TaskChanges {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 160
        taskId: root.task ? root.task.id : ""
        run: root.run
        revision: root.task ? root.task.updatedAt || 0 : 0
    }
}
