pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import "../../services/ai/AgentTimeline.js" as Timeline
import "../lib/Diff.js" as Diff

// One tool call in a timeline: icon + title + status; expands to input,
// output and (for edits) the diff.
StyledRect {
    id: root

    property string title: ""
    property string tool: ""
    property string category: "other"
    property string status: "running"   // running | done | error | denied | ask | pending
    property string input: ""
    property string output: ""
    property bool isError: false
    property string diff: ""
    property string path: ""
    property bool expanded: false
    property bool compact: false
    property string decision: ""        // allow | allow_session | auto | deny (permission answered)

    readonly property var diffStats: diff ? Diff.stats(Diff.parse(diff, path)) : null
    readonly property string inputText: {
        if (!input)
            return "";
        try {
            const o = JSON.parse(input);
            if (o && typeof o === "object" && o.command)
                return "$ " + o.command;
            return JSON.stringify(o, null, 2);
        } catch (e) {
            return input;
        }
    }

    variant: hover.hovered || expanded ? "focus" : "common"
    radius: Styling.radius(-4)
    border.width: 1
    border.color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.55)
    implicitHeight: col.implicitHeight + 12
    clip: true

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hover
    }

    function _icon(c) {
        const name = Timeline.categoryIcon(c);
        return {
            eye: Icons.eye,
            pencil: Icons.pencil,
            terminal: Icons.terminal,
            globe: Icons.globe,
            plug: Icons.plug
        }[name] || Icons.wrench;
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        anchors.leftMargin: 10
        spacing: 6

        MouseArea {
            Layout.fillWidth: true
            implicitHeight: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded

            RowLayout {
                anchors.fill: parent
                spacing: 8

                Text {
                    text: root._icon(root.category)
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: root.status === "error" || root.status === "denied" ? Colors.error : Colors.primary
                }
                Text {
                    Layout.fillWidth: true
                    text: root.title || root.tool
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurface
                    elide: Text.ElideMiddle
                }
                Text {
                    visible: root.diffStats !== null
                    text: root.diffStats ? "+" + root.diffStats.added : ""
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-3)
                    color: Colors.success
                }
                Text {
                    visible: root.diffStats !== null
                    text: root.diffStats ? "−" + root.diffStats.removed : ""
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-3)
                    color: Colors.error
                }
                Text {
                    visible: root.decision === "allow" || root.decision === "allow_session"
                    text: Icons.shieldCheck
                    font.family: Icons.font
                    font.pixelSize: 12
                    color: Colors.outline
                    HoverHandler {
                        id: badgeHover
                    }
                    StyledToolTip {
                        tooltipText: root.decision === "allow_session" ? I18n.t("ai.perm_allowed_session") : I18n.t("ai.perm_allowed")
                        show: badgeHover.hovered
                    }
                }
                Spinner {
                    running: root.status === "running" || root.status === "pending"
                    font.pixelSize: 12
                }
                Text {
                    visible: root.status === "done" || root.status === "error" || root.status === "denied" || root.status === "ask"
                    text: root.status === "done" ? Icons.accept : (root.status === "ask" ? Icons.shieldWarning : Icons.cancel)
                    font.family: Icons.font
                    font.pixelSize: 12
                    color: root.status === "done" ? Colors.success : (root.status === "ask" ? Colors.warning : Colors.error)
                }
                Text {
                    text: root.expanded ? Icons.caretUp : Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: 10
                    color: Colors.outline
                }
            }
        }

        Text {
            visible: root.expanded && root.inputText.length > 0
            Layout.fillWidth: true
            text: root.inputText
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 30
            elide: Text.ElideRight
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.monoFontSize(-3)
            color: Colors.overSurfaceVariant
        }

        DiffView {
            visible: root.diff.length > 0 && root.expanded
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            diff: root.diff
            path: root.path
            maxRows: root.expanded ? 400 : 12
            showHeader: root.expanded
        }

        StyledRect {
            visible: root.expanded && root.output.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            variant: "internalbg"
            radius: Styling.radius(-6)
            implicitHeight: outText.implicitHeight + 12
            Text {
                id: outText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                anchors.leftMargin: 8
                text: root.output.length > 6000 ? root.output.substring(0, 6000) + "\n…" : root.output
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 40
                elide: Text.ElideRight
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-3)
                color: root.isError ? Colors.error : Colors.overSurface
            }
        }
    }
}
