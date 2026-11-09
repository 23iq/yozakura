pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
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
    radius: Look.radius("control")
    implicitHeight: col.implicitHeight + (detailed || expanded ? 12 : 6)
    clip: true

    Behavior on implicitHeight {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 3
            easing.type: Motion.morph.easing
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
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s

            Item {
                implicitWidth: 16
                implicitHeight: 16
                Spinner {
                    anchors.centerIn: parent
                    running: root.status === "running" || root.status === "pending"
                    font.pixelSize: BarLook.size("caption")
                }
                Icon {
                    role: "secondary"
                    anchors.centerIn: parent
                    visible: !(root.status === "running" || root.status === "pending")
                    icon: root.failed ? (root.status === "denied" ? Icons.shieldWarning : Icons.xCircle) : Icons.checkCircle
                    size: BarLook.size("secondary")
                    color: root.failed ? Colors.error : Colors.success
                }
            }
            Icon {
                role: "caption"
                tone: "muted"
                icon: root._icon(root.category)
                size: BarLook.size("caption")
            }
            AiText {
                objectName: "actionTitle"
                role: "secondary"
                Layout.fillWidth: true
                text: root.undone ? I18n.t("ai.action_undone").arg(root.title || root.tool) : (root.title || root.tool)
                font.strikeout: root.undone
                color: root.failed ? Colors.error : Colors.overSurface
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            AiText {
                mono: true
                role: "caption"
                visible: root.diffStats !== null
                text: root.diffStats ? "+" + root.diffStats.added + " −" + root.diffStats.removed : ""
            }
            Icon {
                role: "caption"
                tone: "muted"
                visible: root.decision === "allow_session" || root.decision === "allow"
                icon: Icons.shieldCheck
                size: BarLook.size("caption")
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
                icon: Icons.arrowCounterClockwise
                text: root.undoError ? I18n.t("ai.undo_retry") : (root.undoInfo && root.undoInfo.label ? root.undoInfo.label : I18n.t("ai.undo"))
                maxLabelWidth: 120
                quiet: true
                onClicked: root.undoRequested(root.undoInfo)
            }
            IconButton {
                visible: root.hasDetails
                icon: root.expanded ? Icons.caretUp : Icons.caretDown
                tooltip: root.expanded ? I18n.t("ai.hide_details") : I18n.t("ai.details")
                size: "xs"
                onClicked: root.expanded = !root.expanded
            }
        }

        AiText {
            objectName: "actionUndoError"
            role: "caption"
            visible: root.undoError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Space.xl
            text: I18n.t("ai.undo_failed") + " " + root.undoError
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Type.danger
        }

        AiText {
            mono: true
            role: "caption"
            visible: root.expanded && root.summary.length > 0 && root.diff.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: Space.xl
            text: root.summary
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 12
            elide: Text.ElideRight
            color: Type.secondary
        }

        DiffView {
            visible: root.expanded && root.diff.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: Space.xs / 2
            diff: root.diff
            path: root.path
            maxRows: root.detailed ? 400 : 40
        }

        StyledRect {
            visible: root.expanded && root.output.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Space.xl
            Layout.bottomMargin: Space.xs / 2
            variant: "internalbg"
            radius: Look.radius("small")
            implicitHeight: outText.implicitHeight + 2 * Space.s
            AiText {
                id: outText
                mono: true
                role: "caption"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.s
                anchors.leftMargin: Space.s
                text: root.output.length > 6000 ? root.output.substring(0, 6000) + "\n…" : root.output
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 40
                elide: Text.ElideRight
                color: root.isError ? Colors.error : Colors.overSurface
            }
        }
    }
}
