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
    radius: Styling.radius(-2)
    implicitHeight: col.implicitHeight + 24
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
            plug: Icons.plug
        }[name] || Icons.wrench;
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledRect {
                variant: root.pending ? "primary" : (root.status === "allowed" ? "common" : "error")
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Styling.radius(-4)
                Text {
                    anchors.centerIn: parent
                    text: root.pending ? Icons.shieldWarning : (root.status === "allowed" ? Icons.checkCircle : Icons.xCircle)
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: Styling.srItem(parent.variant)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.pending ? I18n.t("ai.perm_wants").replace("%1", root.agentLabel || I18n.t("ai.the_agent")) : (root.status === "allowed" ? (root.decision === "allow_session" ? I18n.t("ai.perm_allowed_session") : (root.decision === "auto" ? I18n.t("ai.perm_auto") : I18n.t("ai.perm_allowed"))) : I18n.t("ai.perm_denied"))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                }
                RowLayout {
                    spacing: 6
                    Layout.fillWidth: true
                    Text {
                        text: root._icon(root.category)
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: Colors.overSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.title || root.tool
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.DemiBold
                        color: Colors.overSurface
                        elide: Text.ElideMiddle
                    }
                }
            }
        }

        Chip {
            visible: root.pending && (root.detail.length > 0 || root.diff.length > 0)
            label: I18n.t("ai.details")
            trailingIcon: root.detailsOpen ? Icons.caretUp : Icons.caretDown
            variant: "transparent"
            onClicked: root.detailsOpen = !root.detailsOpen
        }

        Text {
            visible: root.detailsOpen && root.pending && root.detail.length > 0 && root.diff.length === 0
            Layout.fillWidth: true
            text: root.detail
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 8
            elide: Text.ElideRight
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.monoFontSize(-3)
            color: Colors.overSurfaceVariant
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
            spacing: 6

            Button {
                id: allowBtn
                text: I18n.t("ai.allow")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("allow")
                Layout.preferredHeight: 30
                contentItem: Text {
                    text: allowBtn.text
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Styling.srItem("primary")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: allowBtn.hovered ? "primaryfocus" : "primary"
                    radius: Styling.radius(-4)
                }
                leftPadding: 14
                rightPadding: 14
            }
            Button {
                id: sessionBtn
                visible: root.sessionAllowed
                text: I18n.t("ai.allow_session")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("allow_session")
                Layout.preferredHeight: 30
                contentItem: Text {
                    text: sessionBtn.text
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurface
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: sessionBtn.hovered ? "focus" : "common"
                    radius: Styling.radius(-4)
                }
                leftPadding: 12
                rightPadding: 12
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                id: denyBtn
                text: I18n.t("ai.deny")
                focusPolicy: Qt.NoFocus
                onClicked: root.decided("deny")
                Layout.preferredHeight: 30
                contentItem: Text {
                    text: denyBtn.text
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: denyBtn.hovered ? Styling.srItem("error") : Colors.error
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: StyledRect {
                    variant: "error"
                    radius: Styling.radius(-4)
                    opacity: denyBtn.hovered ? 1 : 0
                }
                leftPadding: 12
                rightPadding: 12
            }
        }

        Text {
            visible: root.pending
            text: I18n.t("ai.perm_keys_hint")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-4)
            color: Colors.outline
            opacity: 0.8
        }
    }
}
