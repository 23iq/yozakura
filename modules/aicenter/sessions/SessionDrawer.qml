pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/EngineSelection.js" as Selection

// History of one space with search and pinning (pinned first, then most
// recent): Assistant = chats and assistant agent sessions, Code = agent
// sessions grouped by project (sessions of tasks live on the task board). Keyboard: type to search, Up/Down, Enter
// opens, Esc closes.
StyledRect {
    id: root

    signal closeRequested

    property bool docked: false          // persistent column (wide sizes)
    variant: docked ? "transparent" : "popup"
    radius: Styling.radius(-2)

    property string space: "assistant"
    property int selectedIndex: 0
    readonly property var entries: Selection.sessions(Ai.store ? Ai.store.chats : [], Ai.drafts ? Ai.drafts.summaries : [], Ai.agents ? Ai.agents.sessions.filter(s => !TasksService.sessionIds[s.id]) : [], search.text, space).map(e => Object.assign({}, e, {
            subtitle: (e.subtitle || "").replace(Quickshell.env("HOME"), "~")
        }))
    // Code groups sessions under a header row per project.
    readonly property var rows: space === "code" ? Selection.projectRows(entries) : entries
    function _move(step) {
        let i = selectedIndex;
        do
            i += step;
        while (i >= 0 && i < rows.length && rows[i].header)
        if (i >= 0 && i < rows.length) {
            selectedIndex = i;
            list.positionViewAtIndex(i, ListView.Contain);
        }
    }

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
            onTextChanged: root.selectedIndex = root.space === "code" ? 1 : 0
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    root._move(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root._move(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.rows[root.selectedIndex] && !root.rows[root.selectedIndex].header)
                        root.open(root.rows[root.selectedIndex]);
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
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Loader {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                sourceComponent: entry.modelData.header ? headerC : rowC
                Component {
                    id: headerC
                    RowLayout {
                        spacing: 6
                        Text {
                            Layout.leftMargin: 8
                            Layout.topMargin: entry.index > 0 ? 10 : 2
                            text: Icons.folder
                            font.family: Icons.font
                            font.pixelSize: BarLook.font(-3)
                            color: Colors.outline
                        }
                        Text {
                            Layout.topMargin: entry.index > 0 ? 10 : 2
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            elide: Text.ElideRight
                            font.family: Config.theme.font
                            font.pixelSize: BarLook.font(-3)
                            font.weight: Font.DemiBold
                            color: Colors.outline
                        }
                    }
                }
                Component {
                    id: rowC
                    SessionRow {
                        entry: entry.modelData
                        selected: Ai.sessionKey === entry.modelData.kind + ":" + entry.modelData.id
                        highlighted: entry.index === root.selectedIndex
                        onOpened: root.open(entry.modelData)
                        onPinToggled: root.togglePin(entry.modelData)
                        onRemoved: root.remove(entry.modelData)
                        onStopped: Ai.stopSession(entry.modelData.kind, entry.modelData.id)
                        onRenamed: title => Ai.renameConversation(entry.modelData.kind, entry.modelData.id, title)
                    }
                }
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
