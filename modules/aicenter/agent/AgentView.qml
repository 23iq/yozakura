pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Agent mode: session strip + timeline; in wide mode the changed files and
// diffs sit next to the conversation.
Item {
    id: root

    property bool wide: false
    property string sessionId: ""     // fixed session (shell control); "" = the active agent session
    readonly property var sessions: Ai.agents
    readonly property var meta: sessions ? (sessionId ? sessions.sessions.find(s => s.id === sessionId) || null : sessions.active) : null
    readonly property var tl: meta ? sessions.timeline(meta.id) : null
    readonly property var diffs: {
        sessions ? sessions.timelineRevision : 0;
        return tl ? tl.state.diffs.slice() : [];
    }

    function agentLabel() {
        if (!meta || !sessions)
            return "";
        const a = sessions.agents.find(x => x.id === meta.agent);
        return a ? a.label : meta.agent;
    }

    AgentStart {
        anchors.centerIn: parent
        width: Math.min(parent.width, 520)
        visible: !root.meta
    }

    RowLayout {
        anchors.fill: parent
        visible: root.meta !== null
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: root.wide ? root.width * 0.52 : root.width
            spacing: 6

            AgentBar {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 6
                session: root.meta
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.tl ? root.tl.model : null
                spacing: 0
                clip: true
                topMargin: 6
                bottomMargin: 12
                leftMargin: 14
                rightMargin: 14
                cacheBuffer: 2000
                boundsBehavior: Flickable.StopAtBounds
                property bool stick: true
                onMovementEnded: stick = atYEnd
                onContentHeightChanged: if (stick)
                    Qt.callLater(positionViewAtEnd)
                onCountChanged: Qt.callLater(positionViewAtEnd)

                delegate: BlockDelegate {
                    width: list.width - list.leftMargin - list.rightMargin
                    agentLabel: root.agentLabel()
                    compactTools: root.wide
                    showThinking: Config.ai.showThinking
                    onPermissionDecided: (id, decision) => Ai.agents.respond(root.meta.id, id, decision)
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }

        ChangesPane {
            visible: root.wide
            Layout.fillHeight: true
            Layout.preferredWidth: root.width * 0.48 - 10
            Layout.bottomMargin: 4
            Layout.rightMargin: 4
            diffs: root.diffs
        }
    }
}
