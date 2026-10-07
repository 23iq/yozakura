import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Right side of the tmux tab: the selected session's pane layout above its
// window chips, or a hint when no session (or the create row) is selected.
Item {
    id: previewPanel

    required property var tab

    property var currentSession: previewPanel.tab.selectedIndex >= 0 && previewPanel.tab.selectedIndex < previewPanel.tab.filteredSessions.length ? previewPanel.tab.filteredSessions[previewPanel.tab.selectedIndex] : null
    readonly property bool hasSession: !!previewPanel.currentSession && previewPanel.currentSession.isCreateButton !== true && previewPanel.currentSession.isCreateSpecificButton !== true

    // Content when a session is selected
    Item {
        anchors.fill: parent
        visible: previewPanel.hasSession

        SectionLabel {
            id: panesLabel
            anchors.top: parent.top
            anchors.topMargin: Space.s
            width: parent.width
            text: previewPanel.currentSession ? previewPanel.currentSession.name : ""
        }

        TmuxPanesPreview {
            anchors.top: panesLabel.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: windowsLabel.top
            anchors.topMargin: Space.m
            anchors.bottomMargin: Space.l
            tab: previewPanel.tab
            currentSession: previewPanel.currentSession
        }

        SectionLabel {
            id: windowsLabel
            anchors.bottom: windowsSection.top
            anchors.bottomMargin: Space.s
            width: parent.width
            text: I18n.t("tmux.windows")
        }

        TmuxWindowsBar {
            id: windowsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Space.chip
            tab: previewPanel.tab
            currentSession: previewPanel.currentSession
        }
    }

    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: Space.s
        visible: !previewPanel.hasSession

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: Type.iconSize("display")
            color: Type.muted
        }

        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "body"
            text: I18n.t("tmux.no_session")
        }

        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            text: I18n.t("tmux.select_session_hint")
        }
    }
}
