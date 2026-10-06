pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Selected native session timeline; workspace panels are owned by the host.
Item {
    id: root
    property string scrollKey: ""
    property bool restoringScroll: false
    property real scrollPosition: 0
    function saveScroll() {
        if (scrollKey && Ai.drafts && !restoringScroll)
            Ai.drafts.setScroll(scrollKey, scrollPosition);
    }
    function restoreScroll() {
        saveScroll();
        scrollKey = Ai.sessionKey;
        restoringScroll = true;
        Qt.callLater(() => {
            scrollPosition = Ai.drafts ? Ai.drafts.scroll(scrollKey) : 0;
            list.contentY = scrollPosition;
            list.stick = list.atYEnd;
            restoringScroll = false;
        });
    }
    Component.onCompleted: restoreScroll()
    Component.onDestruction: saveScroll()
    Connections {
        target: Ai
        function onSessionKeyChanged() {
            root.restoreScroll();
        }
    }

    property bool wide: false
    property string sessionId: ""     // fixed session (shell control); "" = the active agent session
    readonly property var sessions: Ai.agents
    readonly property var meta: sessions ? (sessionId ? sessions.sessions.find(s => s.id === sessionId) || null : Ai.activeAgent) : null
    readonly property var tl: meta ? sessions.timeline(meta.id) : null
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
                onMovementEnded: {
                    stick = atYEnd;
                    root.scrollPosition = contentY;
                    root.saveScroll();
                }
                onContentHeightChanged: if (stick && !root.restoringScroll)
                    Qt.callLater(positionViewAtEnd)
                onCountChanged: if (stick && !root.restoringScroll)
                    Qt.callLater(positionViewAtEnd)

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
    }
}
