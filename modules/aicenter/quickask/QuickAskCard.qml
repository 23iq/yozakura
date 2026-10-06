pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import qs.modules.aicenter.chat
import qs.modules.aicenter.transcript

// Quick ask, a notch module (Visibilities "aiquick", pushed into the
// island like the voice panel): one input, a streamed answer and "continue
// in the sidebar". Enter asks, Esc closes, Ctrl+Enter → sidebar.
FocusScope {
    id: root

    readonly property var session: Ai.quick
    readonly property int lastIndex: session ? session.rows.count - 1 : -1
    property int revision: 0
    readonly property var last: {
        revision;
        return lastIndex >= 0 ? session.rows.get(lastIndex) : null;
    }
    readonly property var lastAssistant: {
        revision;
        if (!session)
            return null;
        for (let i = session.rows.count - 1; i >= 0; i--) {
            const r = session.rows.get(i);
            if (r.role === "assistant" || r.role === "error")
                return Object.assign({
                    index: i
                }, r);
            if (r.role === "user")
                break;
        }
        return null;
    }
    readonly property var askCall: {
        revision;
        if (!lastAssistant || !lastAssistant.toolCalls)
            return null;
        try {
            return JSON.parse(lastAssistant.toolCalls).find(c => c.status === "ask") || null;
        } catch (e) {
            return null;
        }
    }
    readonly property var lastQuestion: {
        revision;
        if (!session)
            return "";
        for (let i = session.rows.count - 1; i >= 0; i--)
            if (session.rows.get(i).role === "user")
                return session.rows.get(i).content;
        return "";
    }
    readonly property bool busy: session ? session.busy : false
    readonly property bool hasAnswer: lastAssistant !== null

    implicitWidth: Math.max(380, Config.ai.quickAsk.width ?? 560)
    implicitHeight: col.implicitHeight + 8

    Component.onCompleted: {
        Ai._ensureInit();
        input.forceActiveFocus();
    }

    Connections {
        target: root.session ? root.session.rows : null
        function onDataChanged() {
            root.revision++;
        }
        function onCountChanged() {
            root.revision++;
        }
    }

    function ask() {
        const t = input.text.trim();
        if (!t || root.busy)
            return;
        const atts = GlobalStates.quickAskAttachments || [];
        if (Ai.askQuick(t, atts) === false)
            return;
        GlobalStates.quickAskAttachments = [];
        input.text = "";
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: GlobalStates.quickAskKind === "shell" ? Icons.command : Icons.sparkle
                font.family: Icons.font
                font.pixelSize: 16
                color: Colors.primary
            }
            TextField {
                id: input
                focus: true
                Layout.fillWidth: true
                placeholderText: GlobalStates.quickAskKind === "shell" ? I18n.t("ai.shell_placeholder") : I18n.t("ai.quick_placeholder")
                placeholderTextColor: Colors.outline
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                background: null
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.hideQuickAsk();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                        Ai.continueInSidebar();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.ask();
                        event.accepted = true;
                    }
                }
            }
            Spinner {
                running: root.busy
            }
            Chip {
                visible: Ai.quickModel !== null
                image: Ai.quickModel ? Ai.quickModel.icon : ""
                label: Ai.quickModel ? Ai.quickModel.name : ""
                maxLabelWidth: 140
                onClicked: {
                    GlobalStates.hideQuickAsk();
                    if (!GlobalStates.assistantVisible)
                        GlobalStates.toggleAssistant();
                    Ai.modelSelectionRequested();
                }
            }
        }

        AttachmentStrip {
            Layout.fillWidth: true
            attachments: GlobalStates.quickAskAttachments || []
            removable: true
            onRemoveRequested: index => {
                const attachments = (GlobalStates.quickAskAttachments || []).slice();
                attachments.splice(index, 1);
                GlobalStates.quickAskAttachments = attachments;
            }
        }

        Flickable {
            id: answerFlick
            visible: root.hasAnswer
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(answer.implicitHeight, 340)
            contentHeight: answer.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: if (root.busy)
                contentY = Math.max(0, contentHeight - height)
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: answer
                width: answerFlick.width
                spacing: 8
                Text {
                    visible: root.lastQuestion.length > 0
                    Layout.fillWidth: true
                    text: root.lastQuestion
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                }
                ThinkingBlock {
                    visible: root.lastAssistant !== null && root.lastAssistant.thinking.length > 0 && Config.ai.showThinking
                    Layout.fillWidth: true
                    text: root.lastAssistant ? root.lastAssistant.thinking : ""
                    streaming: root.busy && root.lastAssistant !== null && root.lastAssistant.content.length === 0
                }
                MarkdownView {
                    Layout.fillWidth: true
                    text: root.lastAssistant ? root.lastAssistant.content : ""
                    textColor: root.lastAssistant && root.lastAssistant.role === "error" ? Colors.error : Colors.overBackground
                    streaming: root.busy
                }
                PermissionCard {
                    visible: root.askCall !== null
                    Layout.fillWidth: true
                    title: root.askCall ? root.askCall.title : ""
                    tool: root.askCall ? root.askCall.tool : ""
                    category: root.askCall ? root.askCall.category : "mcp"
                    detail: root.askCall ? JSON.stringify(root.askCall.args || {}, null, 2) : ""
                    onDecided: d => root.session.respond(root.lastAssistant.index, root.askCall.id, d)
                }
            }
        }

        RowLayout {
            visible: root.hasAnswer
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: I18n.t("ai.quick_keys")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                color: Colors.outline
                Layout.fillWidth: true
            }
            CopyButton {
                copyText: root.lastAssistant ? root.lastAssistant.content : ""
            }
            Chip {
                glyph: Icons.sidebarSimple
                label: I18n.t("ai.to_sidebar")
                onClicked: Ai.continueInSidebar()
            }
        }
    }
}
