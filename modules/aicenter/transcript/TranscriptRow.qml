pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import "Transcript.js" as Transcript

// Delegate of TranscriptView: one normalised row (see Transcript.js).
Item {
    id: root

    required property int index
    required property string kind
    required property string text
    required property string engine
    required property string status
    required property bool streaming
    required property string attachments
    required property string title
    required property string tool
    required property string category
    required property string input
    required property string output
    required property bool isError
    required property string path
    required property string diff
    required property string decision
    required property string options
    required property string undo
    required property string undoState
    required property string ref
    required property int source
    required property double ts

    property bool detailed: false
    property bool canRetry: false
    property string agentLabel: ""
    property string previousKind: ""

    signal retryRequested(int source)
    signal decided(int source, string ref, string decision)
    signal undoRequested(var descriptor, string key)

    readonly property bool groupStart: Transcript.startsGroup(previousKind, kind)

    implicitHeight: loader.implicitHeight + (index === 0 ? 0 : (groupStart ? BarLook.groupGap : BarLook.gap))

    function _parse(s, fallback) {
        try {
            return s ? JSON.parse(s) : fallback;
        } catch (e) {
            return fallback;
        }
    }

    Loader {
        id: loader
        y: root.index === 0 ? 0 : (root.groupStart ? BarLook.groupGap : BarLook.gap)
        width: parent.width
        sourceComponent: {
            switch (root.kind) {
            case "user":
                return userC;
            case "assistant":
                return assistantC;
            case "thinking":
                return thinkingC;
            case "action":
            case "diff":
                return actionC;
            case "permission":
                return permissionC;
            case "error":
                return errorC;
            case "compacted":
                return compactedC;
            default:
                return noticeC;
            }
        }
    }

    Component {
        id: userC
        UserMessage {
            text: root.text
            attachments: root._parse(root.attachments, [])
            ts: root.ts
        }
    }
    Component {
        id: assistantC
        AssistantMessage {
            text: root.text
            engine: root.engine
            streaming: root.streaming
            groupStart: root.groupStart
            canRetry: root.canRetry
            ts: root.ts
            onRetryRequested: root.retryRequested(root.source)
        }
    }
    Component {
        id: thinkingC
        ThinkingBlock {
            text: root.text
            streaming: root.streaming
            expanded: BarLook.thinkingExpanded
        }
    }
    Component {
        id: actionC
        ActionRow {
            detailed: root.detailed
            title: root.title || (root.kind === "diff" ? I18n.t("ai.changes") : "")
            tool: root.tool
            category: root.category
            status: root.status
            input: root.input
            output: root.output
            isError: root.isError
            diff: root.diff
            path: root.path
            decision: root.decision
            undo: root.undo
            undoState: root.undoState
            onUndoRequested: descriptor => root.undoRequested(descriptor, Transcript.undoKey({
                    ref: root.ref,
                    undo: root.undo
                }))
        }
    }
    Component {
        id: permissionC
        PermissionCard {
            title: root.title
            tool: root.tool
            category: root.category
            status: root.status
            decision: root.decision
            diff: root.diff
            path: root.path
            agentLabel: root.agentLabel
            sessionAllowed: root.options === "" || root.options.indexOf("allow_session") >= 0
            detail: {
                const o = root._parse(root.input, null);
                return o && o.command ? "$ " + o.command : (o ? JSON.stringify(o, null, 2) : root.input);
            }
            Component.onCompleted: if (pending)
                forceActiveFocus()
            onDecided: d => root.decided(root.source, root.ref, d)
        }
    }
    Component {
        id: errorC
        RowLayout {
            spacing: 8
            Text {
                Layout.alignment: Qt.AlignTop
                text: Icons.warning
                font.family: Icons.font
                font.pixelSize: BarLook.font(0)
                color: Colors.error
            }
            Text {
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-1)
                color: Colors.error
            }
            IconButton {
                visible: root.canRetry
                glyph: Icons.arrowCounterClockwise
                tooltip: I18n.t("ai.retry")
                size: 24
                iconSize: 13
                onClicked: root.retryRequested(root.source)
            }
        }
    }
    Component {
        id: compactedC
        CompactedMarker {
            summary: root.text
        }
    }
    Component {
        id: noticeC
        Text {
            text: root.text
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.MarkdownText
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-2)
            color: Colors.outline
        }
    }
}
