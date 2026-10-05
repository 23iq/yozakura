import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config

// Right side of the tmux tab: the selected session's pane layout above its
// window chips, or a hint when no session (or the create row) is selected.
Item {
    id: previewPanel

    required property var tab

    property var currentSession: previewPanel.tab.selectedIndex >= 0 && previewPanel.tab.selectedIndex < previewPanel.tab.filteredSessions.length ? previewPanel.tab.filteredSessions[previewPanel.tab.selectedIndex] : null
    readonly property bool hasSession: {
        if (!previewPanel.currentSession)
            return false;
        if (previewPanel.currentSession.isCreateButton === true)
            return false;
        if (previewPanel.currentSession.isCreateSpecificButton === true)
            return false;
        return true;
    }

    // Content when a session is selected
    Item {
        anchors.fill: parent
        visible: previewPanel.hasSession

        TmuxPanesPreview {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: separator.top
            anchors.bottomMargin: 8
            tab: previewPanel.tab
            currentSession: previewPanel.currentSession
        }

        Rectangle {
            id: separator
            anchors.bottom: windowsSection.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            radius: Styling.radius(0)
            color: Colors.surface
        }

        TmuxWindowsBar {
            id: windowsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32
            tab: previewPanel.tab
            currentSession: previewPanel.currentSession
        }
    }

    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: !previewPanel.hasSession

        Text {
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: 48
            color: Colors.surfaceBright
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
        }

        Text {
            text: I18n.t("tmux.no_session")
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            font.weight: Font.Bold
            color: Colors.overBackground
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: I18n.t("tmux.select_session_hint")
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.outline
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
