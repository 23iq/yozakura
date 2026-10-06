pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common

// One board section ("Waiting for you", "Running", ...): a header with the
// count (click folds it) and its cards. As a column (`column: true`) the
// cards scroll inside the section; in the list they stack.
ColumnLayout {
    id: root

    property var section: ({
            "id": "",
            "tasks": [],
            "count": 0,
            "collapsed": false
        })
    property bool column: false
    property string selectedId: ""
    property string cursorId: ""
    property real now: Date.now()
    signal opened(string id)
    signal toggled

    readonly property var icons: ({
            "waiting": Icons.hand,
            "running": Icons.robot,
            "review": Icons.eye,
            "queued": Icons.hourglass,
            "done": Icons.checkCircle
        })
    readonly property var roles: ({
            "waiting": "warning",
            "running": "primary",
            "review": "secondary",
            "queued": "outline",
            "done": "success"
        })

    objectName: "boardSection_" + section.id
    spacing: 6

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + 10
        radius: Styling.radius(-4)
        variant: headerHover.hovered ? "common" : "transparent"
        HoverHandler {
            id: headerHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.toggled()
        }
        RowLayout {
            id: header
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 6
            Glyph {
                text: root.icons[root.section.id] || Icons.circle
                role: root.roles[root.section.id] || "outline"
                size: -2
            }
            UiText {
                text: I18n.t("ai.tasks.section." + root.section.id)
                strong: true
                size: -2
            }
            StyledRect {
                implicitWidth: countText.implicitWidth + 10
                implicitHeight: countText.implicitHeight + 2
                radius: height / 2
                variant: root.section.id === "waiting" && root.section.count > 0 ? "primary" : "internalbg"
                UiText {
                    id: countText
                    anchors.centerIn: parent
                    text: root.section.count
                    size: -4
                    color: Styling.srItem(parent.variant)
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Glyph {
                text: root.section.collapsed ? Icons.caretRight : Icons.caretDown
                role: "outline"
                size: -4
            }
        }
    }

    // List mode: stacked cards.
    Repeater {
        model: !root.column && !root.section.collapsed ? root.section.tasks : []
        delegate: TaskCard {
            required property var modelData
            Layout.fillWidth: true
            task: modelData
            now: root.now
            selected: modelData.id === root.selectedId
            current: modelData.id === root.cursorId
            onOpened: root.opened(modelData.id)
        }
    }

    // Column mode: a scrolling list of cards.
    ListView {
        id: list
        visible: root.column
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.column && !root.section.collapsed ? root.section.tasks : []
        delegate: TaskCard {
            required property var modelData
            width: list.width
            task: modelData
            now: root.now
            selected: modelData.id === root.selectedId
            current: modelData.id === root.cursorId
            onOpened: root.opened(modelData.id)
        }
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
}
