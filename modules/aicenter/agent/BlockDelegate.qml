pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown

// Renders one agent timeline block (see AgentTimeline.js).
Item {
    id: root

    required property int index
    required property string type
    required property string text
    required property string tool
    required property string title
    required property string category
    required property string status
    required property string input
    required property string output
    required property bool isError
    required property string path
    required property string diff
    required property string key
    required property string decision
    required property bool linked
    required property string options

    property string agentLabel: ""
    property bool compactTools: false
    property bool showThinking: true

    signal permissionDecided(string requestId, string decision)

    // A tool row waiting for permission is shown as the permission card; once
    // answered, the card folds back into the tool row.
    readonly property bool folded: (type === "diff" && compactTools) || (type === "thinking" && !showThinking) || (type === "tool" && status === "ask") || (type === "permission" && linked && status !== "pending")
    implicitHeight: folded ? 0 : loader.implicitHeight + 10
    visible: !folded

    Loader {
        id: loader
        width: parent.width
        sourceComponent: {
            switch (root.type) {
            case "user":
                return userC;
            case "assistant":
                return textC;
            case "thinking":
                return thinkC;
            case "tool":
                return toolC;
            case "permission":
                return permC;
            case "diff":
                return diffC;
            case "error":
                return errorC;
            default:
                return noticeC;
            }
        }
    }

    Component {
        id: userC
        Item {
            implicitHeight: bubble.implicitHeight
            StyledRect {
                id: bubble
                anchors.right: parent.right
                width: Math.min(parent.width * 0.86, body.implicitWidth + 28)
                implicitHeight: body.implicitHeight + 18
                variant: "primary"
                radius: Styling.radius(2)
                TextEdit {
                    id: body
                    x: 14
                    y: 9
                    width: Math.min(implicitWidth, root.width * 0.86 - 28)
                    text: root.text
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Styling.srItem("primary")
                }
            }
        }
    }
    Component {
        id: textC
        MarkdownView {
            text: root.text
            streaming: root.status === "streaming"
        }
    }
    Component {
        id: thinkC
        ThinkingBlock {
            text: root.text
            streaming: root.status === "streaming"
        }
    }
    Component {
        id: toolC
        ToolCard {
            title: root.title
            tool: root.tool
            category: root.category
            status: root.status
            input: root.input
            output: root.output
            isError: root.isError
            diff: root.diff
            path: root.path
            decision: root.decision
            compact: root.compactTools
        }
    }
    Component {
        id: permC
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
                try {
                    const o = JSON.parse(root.input || "{}");
                    return o.command ? "$ " + o.command : JSON.stringify(o, null, 2);
                } catch (e) {
                    return root.input;
                }
            }
            Component.onCompleted: if (pending)
                forceActiveFocus()
            onDecided: d => root.permissionDecided(root.key.substring(5), d)
        }
    }
    Component {
        id: diffC
        ToolCard {
            title: root.path || I18n.t("ai.changes")
            category: "write"
            status: "done"
            diff: root.diff
            path: root.path
        }
    }
    Component {
        id: errorC
        RowLayout {
            spacing: 8
            Text {
                text: Icons.warning
                font.family: Icons.font
                font.pixelSize: 14
                color: Colors.error
            }
            Text {
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.error
            }
        }
    }
    Component {
        id: noticeC
        Text {
            text: root.text
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }
}
