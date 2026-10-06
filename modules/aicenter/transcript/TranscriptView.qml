pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.aicenter.common

// The conversation of any engine: an HTTP chat (`session`, a ChatSession)
// or a CLI agent session (`agentId`). Styles: "compact" (Assistant) and
// "detailed" (Code: tool calls as cards). Keeps the scroll position per
// session and follows streaming output (ai.behavior.autoScroll).
Item {
    id: root

    property var session: null          // ChatSession (HTTP)
    property string agentId: ""         // agent session id (CLI)
    property string style: "compact"
    property string agentLabel: ""
    // Scroll memory key; "" = the open conversation (Ai.sessionKey).
    property string persistKey: ""

    readonly property string kind: agentId ? "agent" : "chat"
    readonly property var timeline: agentId && Ai.agents ? Ai.agents.timeline(agentId) : null
    readonly property int count: model.rows.count

    property TranscriptModel model: TranscriptModel {
        kind: root.kind
        source: root.agentId ? (root.timeline ? root.timeline.model : null) : (root.session ? root.session.rows : null)
        showThinking: BarLook.showThinking
    }

    // Scroll position per session (Ai.drafts), restored when switching back.
    property string scrollKey: ""
    property bool restoringScroll: false
    property real scrollPosition: 0
    function saveScroll() {
        if (scrollKey && Ai.drafts && !restoringScroll)
            Ai.drafts.setScroll(scrollKey, scrollPosition);
    }
    function restoreScroll() {
        saveScroll();
        scrollKey = root.persistKey || Ai.sessionKey;
        restoringScroll = true;
        Qt.callLater(() => {
            scrollPosition = Ai.drafts ? Ai.drafts.scroll(scrollKey) : 0;
            list.contentY = scrollPosition;
            list.stick = list.atYEnd;
            restoringScroll = false;
        });
    }
    Component.onCompleted: restoreScroll()
    onPersistKeyChanged: restoreScroll()
    Component.onDestruction: saveScroll()
    Connections {
        target: Ai
        function onSessionKeyChanged() {
            if (!root.persistKey)
                root.restoreScroll();
        }
    }

    function decide(source, ref, decision) {
        if (root.kind === "agent")
            Ai.agents.respond(root.agentId, ref, decision);
        else if (root.session)
            root.session.respond(source, ref, decision);
    }

    ListView {
        id: list
        objectName: "workspaceChatList"
        anchors.fill: parent
        model: root.model.rows
        clip: true
        topMargin: 12
        bottomMargin: 16
        leftMargin: BarLook.pad
        rightMargin: BarLook.pad
        cacheBuffer: 2000
        boundsBehavior: Flickable.StopAtBounds
        property bool stick: true

        onMovementEnded: {
            stick = atYEnd;
            root.scrollPosition = contentY;
            root.saveScroll();
        }
        function follow() {
            if (stick && BarLook.autoScroll && !root.restoringScroll)
                Qt.callLater(positionViewAtEnd);
        }
        onContentHeightChanged: follow()
        onCountChanged: follow()

        add: Transition {
            enabled: BarLook.animDuration > 0
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: BarLook.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        delegate: TranscriptRow {
            width: list.width - list.leftMargin - list.rightMargin
            detailed: root.style === "detailed"
            canRetry: root.kind === "chat" && root.session !== null
            agentLabel: root.agentLabel
            previousKind: root.model.kindAt(index - 1)
            onRetryRequested: source => root.session.retry(source)
            onDecided: (source, ref, decision) => root.decide(source, ref, decision)
            onUndoRequested: descriptor => Ai.undoAction(descriptor)
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
}
