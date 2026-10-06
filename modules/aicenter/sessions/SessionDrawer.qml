pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../services/ai/EngineSelection.js" as Selection

// History: chats, shell-control chats and agent sessions with search and
// pinning (pinned first, then most recent). Keyboard: type to search,
// Up/Down, Enter opens, Esc closes.
StyledRect {
    id: root

    signal closeRequested

    variant: "popup"
    radius: Styling.radius(-2)

    property int selectedIndex: 0
    readonly property var entries: Selection.sessions(Ai.store ? Ai.store.chats : [], Ai.drafts ? Ai.drafts.summaries : [], Ai.agents ? Ai.agents.sessions : [], search.text).map(e => Object.assign({}, e, {
            subtitle: (e.subtitle || "").replace(Quickshell.env("HOME"), "~")
        }))

    function focusSearch() {
        search.forceActiveFocus();
        if (Ai.store)
            Ai.store.refresh();
        if (Ai.agents)
            Ai.agents.refresh();
    }

    function open(e) {
        if (!e)
            return;
        Ai.openConversation(e.kind, e.id);
        root.closeRequested();
    }

    function togglePin(e) {
        Ai.pinConversation(e.kind, e.id, !e.pinned);
    }
    function remove(e) {
        Ai.removeConversation(e.kind, e.id);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: I18n.t("ai.search_sessions")
            placeholderTextColor: Colors.outline
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            leftPadding: 30
            background: StyledRect {
                variant: "common"
                radius: Styling.radius(-4)
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.magnifyingGlass
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: Colors.outline
                }
            }
            onTextChanged: root.selectedIndex = 0
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    root.selectedIndex = Math.min(root.entries.length - 1, root.selectedIndex + 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.open(root.entries[root.selectedIndex]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.closeRequested();
                    event.accepted = true;
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.entries
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: SessionRow {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                entry: entry.modelData
                selected: Ai.sessionKey === entry.modelData.kind + ":" + entry.modelData.id
                onOpened: root.open(entry.modelData)
                onPinToggled: root.togglePin(entry.modelData)
                onRemoved: root.remove(entry.modelData)
                onStopped: Ai.stopSession(entry.modelData.kind, entry.modelData.id)
                onRenamed: title => Ai.renameConversation(entry.modelData.kind, entry.modelData.id, title)
            }
        }

        Text {
            visible: root.entries.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 20
            text: search.text ? I18n.t("ai.no_matches") : I18n.t("ai.no_sessions")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }
}
