pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import qs.modules.services

// Conversation list for chat and shell modes (ChatSession.rows).
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

    property var session: null
    property string mode: "chat"
    readonly property bool empty: !session || session.rows.count === 0

    signal suggestion(string text, string context)

    WelcomeView {
        anchors.centerIn: parent
        width: Math.min(parent.width, 520)
        visible: root.empty
        mode: root.mode
        onSuggestion: (text, context) => root.suggestion(text, context)
    }

    ListView {
        id: list
        objectName: "workspaceChatList"
        anchors.fill: parent
        visible: !root.empty
        model: root.session ? root.session.rows : null
        spacing: 18
        clip: true
        topMargin: 12
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

        delegate: MessageCard {
            width: list.width - list.leftMargin - list.rightMargin
            session: root.session
            showThinking: Config.ai.showThinking
            previousRole: index > 0 && root.session ? root.session.rows.get(index - 1).role : ""
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
}
