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
import "Transcript.js" as Transcript

// One tool call: status icon, one-line summary, diff stats and an Undo
// button (when the tool returned an undo descriptor); expands to the input,
// the diff and the output. `detailed` draws it as a card (Code space).
StyledRect {
    id: root
    objectName: "actionRow"

    property bool detailed: false
    property string title: ""
    property string tool: ""
    property string category: "other"
    property string status: "running"   // running | done | error | denied | pending
    property string input: ""
    property string output: ""
    property bool isError: false
    property string diff: ""
    property string path: ""
    property string decision: ""        // allow | allow_session | auto | deny
    property string undo: ""            // JSON descriptor, "" = not undoable
    property bool expanded: BarLook.toolsExpanded
    // "" | pending | done | error:<message> (Ai.undoStates via the row)
    property string undoState: ""
    readonly property bool undone: undoState === "done"
    readonly property bool undoBusy: undoState === "pending"
    readonly property string undoError: undoState.indexOf("error:") === 0 ? undoState.substring(6) : ""

    signal undoRequested(var descriptor)

    readonly property var undoInfo: Transcript.undoOf({
        undo: undo
    })
    readonly property bool canUndo: undoInfo !== null && status === "done" && !undone && !undoBusy
    readonly property var diffStats: diff ? Diff.stats(Diff.parse(diff, path)) : null
    readonly property string summary: Transcript.inputSummary(input)
    readonly property bool failed: status === "error" || status === "denied" || isError
    readonly property bool hasDetails: summary.length > 0 || output.length > 0 || diff.length > 0

    variant: detailed || expanded ? (hover.hovered ? "focus" : "common") : (hover.hovered ? "common" : "transparent")
    radius: Styling.radius(-4)
    implicitHeight: col.implicitHeight + (detailed || expanded ? 12 : 6)
    clip: true

    Behavior on implicitHeight {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 3
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hover
    }

    function _icon(c) {
        return ({
                eye: Icons.eye,
                pencil: Icons.pencil,
                terminal: Icons.terminal,
                globe: Icons.globe,
                plug: Icons.plug,
                shieldWarning: Icons.shieldWarning
            })[Timeline.categoryIcon(c)] || Icons.wrench;
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.detailed || root.expanded ? 6 : 3
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                implicitWidth: 16
                implicitHeight: 16
                Spinner {
                    anchors.centerIn: parent
                    running: root.status === "running" || root.status === "pending"
                    font.pixelSize: BarLook.font(-3)
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(root.status === "running" || root.status === "pending")
                    text: root.failed ? (root.status === "denied" ? Icons.shieldWarning : Icons.xCircle) : Icons.checkCircle
                    font.family: Icons.font
                    font.pixelSize: BarLook.font(-1)
                    color: root.failed ? Colors.error : Colors.success
                }
            }
            Text {
                text: root._icon(root.category)
                font.family: Icons.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.outline
            }
            Text {
                objectName: "actionTitle"
                Layout.fillWidth: true
                text: root.undone ? I18n.t("ai.action_undone").arg(root.title || root.tool) : (root.title || root.tool)
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-1)
                font.strikeout: root.undone
                color: root.failed ? Colors.error : Colors.overSurface
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                visible: root.diffStats !== null
                text: root.diffStats ? "+" + root.diffStats.added + " −" + root.diffStats.removed : ""
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.mono(-3)
                color: Colors.outline
            }
            Text {
                visible: root.decision === "allow_session" || root.decision === "allow"
                text: Icons.shieldCheck
                font.family: Icons.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.outline
                HoverHandler {
                    id: badgeHover
                }
                StyledToolTip {
                    tooltipText: root.decision === "allow_session" ? I18n.t("ai.perm_allowed_session") : I18n.t("ai.perm_allowed")
                    show: badgeHover.hovered
                }
            }
            Chip {
                objectName: "actionUndo"
                visible: root.canUndo
                glyph: Icons.arrowCounterClockwise
                label: root.undoError ? I18n.t("ai.undo_retry") : (root.undoInfo && root.undoInfo.label ? root.undoInfo.label : I18n.t("ai.undo"))
                maxLabelWidth: 120
                variant: "transparent"
                onClicked: root.undoRequested(root.undoInfo)
            }
            IconButton {
                visible: root.hasDetails
                glyph: root.expanded ? Icons.caretUp : Icons.caretDown
                tooltip: root.expanded ? I18n.t("ai.hide_details") : I18n.t("ai.details")
                size: 22
                iconSize: 11
                onClicked: root.expanded = !root.expanded
            }
        }

        Text {
            objectName: "actionUndoError"
            visible: root.undoError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 24
            text: I18n.t("ai.undo_failed") + " " + root.undoError
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-3)
            color: Colors.error
        }

        Text {
            visible: root.expanded && root.summary.length > 0 && root.diff.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: 24
            text: root.summary
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 12
            elide: Text.ElideRight
            font.family: Config.theme.monoFont
            font.pixelSize: BarLook.mono(-3)
            color: Colors.overSurfaceVariant
        }

        DiffView {
            visible: root.expanded && root.diff.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            diff: root.diff
            path: root.path
            maxRows: root.detailed ? 400 : 40
        }

        StyledRect {
            visible: root.expanded && root.output.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 24
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
                font.pixelSize: BarLook.mono(-3)
                color: root.isError ? Colors.error : Colors.overSurface
            }
        }
    }
}
