pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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
    spacing: Space.s

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + 2 * Space.xs
        radius: Look.radius("control")
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
            anchors.leftMargin: Space.s
            anchors.rightMargin: Space.s
            spacing: Space.s
            Icon {
                role: "caption"
                size: BarLook.size("caption")
                color: Colors[root.roles[root.section.id] || "outline"] ?? Type.text
                icon: root.icons[root.section.id] || Icons.circle
            }
            AiText {
                role: "caption"
                font.weight: Font.DemiBold
                color: Type.text
                text: I18n.t("ai.tasks.section." + root.section.id)
            }
            StyledRect {
                implicitWidth: countText.implicitWidth + 2 * Space.xs
                implicitHeight: countText.implicitHeight + 2 * Space.hairline
                radius: Look.radius("round", height)
                variant: root.section.id === "waiting" && root.section.count > 0 ? "primary" : "internalbg"
                AiText {
                    id: countText
                    role: "caption"
                    anchors.centerIn: parent
                    text: root.section.count
                    color: Styling.srItem(parent.variant)
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Icon {
                role: "caption"
                size: BarLook.size("caption")
                tone: "muted"
                icon: root.section.collapsed ? Icons.caretRight : Icons.caretDown
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
        spacing: Space.s
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
