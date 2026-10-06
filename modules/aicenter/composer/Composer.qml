pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.chat

// Message input: multi-line text, context chips, attach menu, send/stop.
// Enter sends, Shift+Enter newline, Ctrl+Shift+S/V/R/O/W attach context,
// Ctrl+. stops, Esc clears attachments, then text, then closes.
StyledRect {
    id: root

    property bool busy: false
    property string placeholder: I18n.t("ai.ask_anything")
    property var attachments: []
    property alias text: input.text
    property bool compact: false
    property var submitHandler: null

    signal submitted(string text, var attachments)
    signal stopRequested
    signal escapePressed

    variant: "common"
    radius: Styling.radius(2)
    implicitHeight: col.implicitHeight + 16
    border.width: 1
    border.color: input.activeFocus ? Colors.primary : Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.6)

    function focusInput() {
        input.forceActiveFocus();
    }

    function addContext(kind) {
        Ai._ensureInit();
        const key = Ai.sessionKey;
        Ai.context.grab(kind, att => {
            if (!att)
                return;
            if (key === Ai.sessionKey) {
                root.attachments = root.attachments.concat([att]);
            } else if (Ai.drafts) {
                const draft = Ai.drafts.draft(key);
                Ai.drafts.setDraft(key, draft.text || "", (draft.attachments || []).concat([att]));
            }
        });
    }

    function submit() {
        const t = input.text;
        if (root.busy || (!t.trim() && root.attachments.length === 0))
            return;
        if (root.submitHandler && root.submitHandler(t, root.attachments) === false)
            return;
        root.submitted(t, root.attachments);
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
    readonly property var slashMatches: input.text.startsWith("/") && input.text.indexOf(" ") < 0 ? slashCommands.filter(c => c.cmd.startsWith(input.text)) : []
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
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectionColor: Colors.primary
                selectedTextColor: Colors.overPrimary
                background: null
                leftPadding: 6
                rightPadding: 6
                topPadding: 4
                bottomPadding: 4

                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift) {
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
                text: I18n.t("ai.enter_hint")
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
}
