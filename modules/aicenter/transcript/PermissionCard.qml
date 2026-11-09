pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.markdown
import qs.modules.aicenter.common
import qs.modules.components.kit
import "../../services/ai/AgentTimeline.js" as Timeline

// "The agent wants to …" card: Allow / Allow for this session / Deny.
// Keyboard: Enter allow, Shift+Enter allow for session, Esc deny.
StyledRect {
    id: root

    property string title: ""
    property string tool: ""
    property string category: "other"
    property string detail: ""
    property string diff: ""
    property string path: ""
    property string status: "pending"   // pending | allowed | denied
    property string decision: ""
    property string agentLabel: ""
    // False when the backend offers no session rule (interpreters, cd,
    // commands it cannot parse exactly): only Allow / Deny.
    property bool sessionAllowed: true
    property bool detailsOpen: false
    readonly property bool pending: status === "pending"

    signal decided(string decision)

    variant: pending ? "pane" : "common"
    radius: Look.radius("control")
    implicitHeight: col.implicitHeight + 2 * Space.m
    border.width: pending ? 1 : 0
    border.color: Colors.primary
    focus: pending
    activeFocusOnTab: pending

    Keys.onPressed: event => {
        if (!root.pending)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.decided(event.modifiers & Qt.ShiftModifier && root.sessionAllowed ? "allow_session" : "allow");
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) {
            root.decided("deny");
            event.accepted = true;
        }
    }

    function _icon(c) {
        const name = Timeline.categoryIcon(c);
        return {
            eye: Icons.eye,
            pencil: Icons.pencil,
            terminal: Icons.terminal,
            globe: Icons.globe,
            plug: Icons.plug,
            shieldWarning: Icons.shieldWarning
        }[name] || Icons.wrench;
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Space.m
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s

            StyledRect {
                variant: root.pending ? "primary" : (root.status === "allowed" ? "common" : "error")
                Layout.preferredWidth: Space.controlXS
                Layout.preferredHeight: Space.controlXS
                radius: Look.radius("control")
                Icon {
                    role: "secondary"
                    anchors.centerIn: parent
                    icon: root.pending ? Icons.shieldWarning : (root.status === "allowed" ? Icons.checkCircle : Icons.xCircle)
                    color: Styling.srItem(parent.variant)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.hairline
                KitText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: root.pending ? I18n.t("ai.perm_wants").replace("%1", root.agentLabel || I18n.t("ai.the_agent")) : (root.status === "allowed" ? (root.decision === "allow_session" ? I18n.t("ai.perm_allowed_session") : (root.decision === "auto" ? I18n.t("ai.perm_auto") : I18n.t("ai.perm_allowed"))) : I18n.t("ai.perm_denied"))
                }
                RowLayout {
                    spacing: Space.s
                    Layout.fillWidth: true
                    Icon {
                        role: "label"
                        tone: "text"
                        icon: root._icon(root.category)
                    }
                    KitText {
                        Layout.fillWidth: true
                        text: root.title || root.tool
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                }
            }
        }

        Chip {
            visible: root.pending && (root.detail.length > 0 || root.diff.length > 0)
            text: I18n.t("ai.details")
            trailingIcon: root.detailsOpen ? Icons.caretUp : Icons.caretDown
            quiet: true
            onClicked: root.detailsOpen = !root.detailsOpen
        }

        KitText {
            role: "caption"
            visible: root.detailsOpen && root.pending && root.detail.length > 0 && root.diff.length === 0
            Layout.fillWidth: true
            text: root.detail
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 8
            elide: Text.ElideRight
            font.family: Type.monoFont
            color: Type.secondary
        }

        DiffView {
            visible: root.detailsOpen && root.pending && root.diff.length > 0
            Layout.fillWidth: true
            diff: root.diff
            path: root.path
            maxRows: 24
        }

        RowLayout {
            visible: root.pending
            Layout.fillWidth: true
            spacing: Space.s

            Button {
                id: allowBtn
                text: I18n.t("ai.allow")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("allow")
                Layout.preferredHeight: Space.controlXS
                contentItem: KitText {
                    role: "secondary"
                    text: allowBtn.text
                    font.weight: Font.DemiBold
                    color: Styling.srItem("primary")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: allowBtn.hovered ? "primaryfocus" : "primary"
                    radius: Look.radius("control")
                }
                leftPadding: Space.m
                rightPadding: Space.m
            }
            Button {
                id: sessionBtn
                visible: root.sessionAllowed
                text: I18n.t("ai.allow_session")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("allow_session")
                Layout.preferredHeight: Space.controlXS
                contentItem: KitText {
                    role: "secondary"
                    text: sessionBtn.text
                    color: Type.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: sessionBtn.hovered ? "focus" : "common"
                    radius: Look.radius("control")
                }
                leftPadding: Space.m
                rightPadding: Space.m
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                id: denyBtn
                text: I18n.t("ai.deny")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("deny")
                Layout.preferredHeight: Space.controlXS
                contentItem: KitText {
                    role: "secondary"
                    text: denyBtn.text
                    color: denyBtn.hovered ? Styling.srItem("error") : Colors.error
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: "error"
                    radius: Look.radius("control")
                    opacity: denyBtn.hovered ? 1 : 0
                }
                leftPadding: Space.m
                rightPadding: Space.m
            }
        }

        KitText {
            role: "caption"
            visible: root.pending
            text: I18n.t("ai.perm_keys_hint")
            opacity: 0.8
        }
    }
}
