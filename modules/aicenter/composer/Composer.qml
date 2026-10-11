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
import qs.modules.aicenter.chat
import "Mentions.js" as Mentions

// Message input: multi-line text, context chips, attach menu, send/stop.
// Enter sends and Shift+Enter adds a line (ai.behavior.enterToSend off:
// Enter adds a line); Ctrl+Enter always sends, Ctrl+Shift+S/V/R/O/W attach context,
// Ctrl+. stops, Esc clears attachments, then text, then closes. Ctrl+V also
// attaches a copied image or copied files, dropping files attaches them, and
// `@` searches the project for a file to mention (it becomes an attachment).
StyledRect {
    id: root

    property bool busy: false
    property string placeholder: I18n.t("ai.ask_anything")
    property var attachments: []
    property alias text: input.text
    property bool compact: false
    property var submitHandler: null
    // Extra `/` commands ([{cmd, desc}], e.g. task templates) and whether
    // the built-in /new /clear /model are offered.
    property var extraCommands: []
    property bool builtinCommands: true
    // Directory `@` searches in
    property string mentionRoot: Quickshell.env("HOME")

    property string lastSent: ""
    property var mention: null
    property var mentionResults: []
    property int mentionIndex: 0
    property bool mentionSearching: false
    property int mentionSeq: 0
    readonly property int maxAttachments: 10

    signal submitted(string text, var attachments)
    signal stopRequested
    signal escapePressed

    variant: "common"
    radius: Styling.radius(2)
    implicitHeight: col.implicitHeight + 16
    border.width: 1
    border.color: input.activeFocus || drop.containsDrag ? Colors.primary : Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.6)

    function focusInput() {
        input.forceActiveFocus();
    }
    // Replace the text and put the cursor at its end (template commands).
    function insert(text) {
        input.text = text;
        input.cursorPosition = text.length;
        input.forceActiveFocus();
    }

    // Adds `att` to the session `key` asked for (its draft when the user has
    // switched sessions meanwhile).
    function deliver(key, att) {
        if (!att)
            return;
        if (key === Ai.sessionKey) {
            if (!att.path || !Mentions.attached(root.attachments, att.path))
                root.attachments = root.attachments.concat([att]).slice(0, root.maxAttachments);
        } else if (Ai.drafts) {
            const draft = Ai.drafts.draft(key);
            Ai.drafts.setDraft(key, draft.text || "", (draft.attachments || []).concat([att]));
        }
    }

    function addContext(kind) {
        Ai._ensureInit();
        const key = Ai.sessionKey;
        Ai.context.grab(kind, att => root.deliver(key, att));
    }

    function addFile(path) {
        Ai._ensureInit();
        const key = Ai.sessionKey;
        Ai.context.file(path, att => root.deliver(key, att));
    }

    // Ctrl+V: the text paste is the TextArea's own; a copied image or copied
    // files (nothing textual on the clipboard) become attachments instead.
    function pasteExtras() {
        Ai._ensureInit();
        Ai.context.clipboardTypes(types => {
            const kind = Mentions.pasteKind(types);
            if (kind === "image") {
                root.addContext("clipboard");
            } else if (kind === "files") {
                Ai.context.clipboardUris(text => Mentions.uriPaths(text).slice(0, 5).forEach(p => root.addFile(p)));
            }
        });
    }

    function updateMention() {
        const m = Mentions.activeMention(input.text, input.cursorPosition);
        mention = m;
        if (!m) {
            mentionResults = [];
            mentionSearching = false;
            mentionSeq++;
            return;
        }
        mentionSearching = true;
        mentionTimer.restart();
    }

    function searchMention() {
        const m = mention;
        if (!m)
            return;
        Ai._ensureInit();
        const seq = ++mentionSeq;
        Ai.context.findFiles(root.mentionRoot, m.query, list => {
            if (seq !== root.mentionSeq)
                return;
            root.mentionSearching = false;
            root.mentionResults = list.slice(0, 8);
            root.mentionIndex = 0;
        });
    }

    function acceptMention(path) {
        const m = mention;
        if (!m)
            return;
        const r = Mentions.accept(input.text, m, path);
        mention = null;
        mentionResults = [];
        mentionSeq++;
        input.text = r.text;
        input.cursorPosition = r.cursor;
        addFile(root.mentionRoot + "/" + path);
        input.forceActiveFocus();
    }

    function submit() {
        const t = input.text;
        if (root.busy || (!t.trim() && root.attachments.length === 0))
            return;
        if (root.submitHandler && root.submitHandler(t, root.attachments) === false)
            return;
        root.submitted(t, root.attachments);
        root.lastSent = t;
        input.text = "";
        root.attachments = [];
    }

    readonly property var slashCommands: [
        {
            cmd: "/new",
            desc: I18n.t("ai.cmd_start_new_chat")
        },
        {
            cmd: "/clear",
            desc: I18n.t("ai.cmd_clear")
        },
        {
            cmd: "/model",
            desc: I18n.t("ai.cmd_switch_model")
        }
    ]
    readonly property bool enterSends: BarLook.behavior.enterToSend !== false
    readonly property var slashMatches: input.text.startsWith("/") && input.text.indexOf(" ") < 0 ? (builtinCommands ? slashCommands : []).concat(extraCommands).filter(c => c.cmd.startsWith(input.text)) : []
    readonly property var contextKeys: ({
            [Qt.Key_S]: "selection",
            [Qt.Key_V]: "clipboard",
            [Qt.Key_R]: "region",
            [Qt.Key_O]: "file",
            [Qt.Key_W]: "window"
        })

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        Repeater {
            model: root.mention ? root.mentionResults : []
            delegate: StyledRect {
                id: hit
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Styling.radius(-6)
                variant: hit.index === root.mentionIndex ? "focus" : "transparent"
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered)
                        root.mentionIndex = hit.index
                }
                TapHandler {
                    onTapped: root.acceptMention(hit.modelData)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: Icons.fileText
                        font.family: Icons.font
                        font.pixelSize: BarLook.font(-1)
                        color: Colors.primary
                    }
                    Text {
                        text: hit.modelData.split("/").pop()
                        font.family: Config.theme.font
                        font.pixelSize: BarLook.font(-1)
                        color: Colors.overSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: hit.modelData.indexOf("/") >= 0 ? hit.modelData.slice(0, hit.modelData.lastIndexOf("/")) : ""
                        font.family: Config.theme.font
                        font.pixelSize: BarLook.font(-2)
                        color: Colors.outline
                        elide: Text.ElideLeft
                    }
                }
            }
        }
        Text {
            visible: root.mention !== null && !root.mentionSearching && root.mentionResults.length === 0 && root.mention.query.length > 0
            Layout.leftMargin: 6
            text: I18n.t("ai.mention_none")
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-2)
            color: Colors.outline
        }

        Repeater {
            model: root.slashMatches
            delegate: RowLayout {
                id: entry
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 8
                Text {
                    text: entry.modelData.cmd
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-2)
                    color: Colors.primary
                }
                Text {
                    Layout.fillWidth: true
                    text: entry.modelData.desc
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                    elide: Text.ElideRight
                }
            }
        }

        AttachmentStrip {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            attachments: root.attachments
            removable: true
            onRemoveRequested: index => {
                const list = root.attachments.slice();
                list.splice(index, 1);
                root.attachments = list;
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Math.max(input.implicitHeight, 24), root.compact ? 90 : 180)
            TextArea {
                id: input
                placeholderText: root.placeholder
                placeholderTextColor: Colors.outline
                wrapMode: TextArea.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(0)
                color: Colors.overBackground
                selectionColor: Colors.primary
                selectedTextColor: Colors.overPrimary
                background: null
                leftPadding: 6
                rightPadding: 6
                topPadding: 4
                bottomPadding: 4
                onTextChanged: root.updateMention()
                onCursorPositionChanged: root.updateMention()

                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    if (root.mention && root.mentionResults.length > 0 && !ctrl) {
                        const n = root.mentionResults.length;
                        if (event.key === Qt.Key_Down) {
                            root.mentionIndex = (root.mentionIndex + 1) % n;
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Up) {
                            root.mentionIndex = (root.mentionIndex + n - 1) % n;
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Tab || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift)) {
                            root.acceptMention(root.mentionResults[root.mentionIndex]);
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Escape) {
                            root.mention = null;
                            root.mentionResults = [];
                            event.accepted = true;
                            return;
                        }
                    }
                    if ((ctrl && !shift && event.key === Qt.Key_V) || (shift && !ctrl && event.key === Qt.Key_Insert)) {
                        root.pasteExtras();
                    } else if (event.key === Qt.Key_Up && !ctrl && !shift && input.text.length === 0 && root.lastSent.length > 0) {
                        input.text = root.lastSent;
                        input.cursorPosition = input.text.length;
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift && (ctrl || root.enterSends)) {
                        if (root.slashMatches.length === 1 && input.text !== root.slashMatches[0].cmd)
                            input.text = root.slashMatches[0].cmd;
                        root.submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab && root.slashMatches.length > 0) {
                        input.text = root.slashMatches[0].cmd + " ";
                        input.cursorPosition = input.text.length;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        if (root.attachments.length > 0)
                            root.attachments = [];
                        else if (input.text.length > 0)
                            input.text = "";
                        else
                            root.escapePressed();
                        event.accepted = true;
                    } else if (ctrl && shift && root.contextKeys[event.key]) {
                        root.addContext(root.contextKeys[event.key]);
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_Period) {
                        root.stopRequested();
                        event.accepted = true;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            IconButton {
                glyph: Icons.plus
                tooltip: I18n.t("ai.attach")
                onClicked: menu.open()
                AttachMenu {
                    id: menu
                    y: -implicitHeight - 6
                    onPicked: kind => root.addContext(kind)
                }
            }
            IconButton {
                glyph: Icons.cursorText
                tooltip: I18n.t("ai.ctx_selection")
                visible: !root.compact
                onClicked: root.addContext("selection")
            }
            IconButton {
                glyph: Icons.selection
                tooltip: I18n.t("ai.ctx_region")
                visible: !root.compact
                onClicked: root.addContext("region")
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                visible: !root.compact && input.text.length > 0
                text: I18n.t(root.enterSends ? "ai.enter_hint" : "ai.ctrl_enter_hint")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                color: Colors.outline
            }
            IconButton {
                glyph: root.busy ? Icons.stop : Icons.paperPlaneRight
                tooltip: root.busy ? I18n.t("ai.stop") + " (Ctrl+.)" : I18n.t("ai.send")
                active: root.busy || input.text.trim().length > 0 || root.attachments.length > 0
                onClicked: root.busy ? root.stopRequested() : root.submit()
            }
        }
    }

    Timer {
        id: mentionTimer
        interval: 90
        onTriggered: root.searchMention()
    }

    // Files dropped on the composer become attachments.
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: event => {
            for (const url of (event.urls || []).slice(0, 5)) {
                const text = url.toString();
                if (text.startsWith("file://"))
                    root.addFile(decodeURIComponent(text.slice(7)));
            }
            root.focusInput();
        }
    }
}
