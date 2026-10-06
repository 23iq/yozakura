pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.aicenter.common

// The task board of a project: columns side by side (wide) or a sectioned
// list (compact, or next to the open task). `board` is TaskModel.board().
Item {
    id: root

    property var board: ({
            "sections": [],
            "total": 0
        })
    property bool columns: false
    property string selectedId: ""
    property string cursorId: ""
    property real now: Date.now()
    signal opened(string id)
    signal toggled(string section)

    // Collapsed sections stay narrow in the column layout.
    readonly property var visibleSections: root.board.sections.filter(s => s.count > 0 || s.id !== "done")

    RowLayout {
        objectName: "boardColumns"
        anchors.fill: parent
        visible: root.columns
        spacing: BarLook.gap
        Repeater {
            model: root.columns ? root.visibleSections : []
            delegate: BoardSection {
                required property var modelData
                Layout.fillHeight: true
                Layout.fillWidth: !modelData.collapsed
                Layout.preferredWidth: modelData.collapsed ? 150 : 260
                Layout.minimumWidth: modelData.collapsed ? 120 : 200
                column: true
                section: modelData
                selectedId: root.selectedId
                cursorId: root.cursorId
                now: root.now
                onOpened: id => root.opened(id)
                onToggled: root.toggled(modelData.id)
            }
        }
    }

    Flickable {
        id: flick
        objectName: "boardList"
        anchors.fill: parent
        visible: !root.columns
        clip: true
        contentHeight: listCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        ColumnLayout {
            id: listCol
            width: flick.width
            spacing: BarLook.gap
            Repeater {
                model: root.columns ? [] : root.board.sections.filter(s => s.count > 0)
                delegate: BoardSection {
                    required property var modelData
                    Layout.fillWidth: true
                    section: modelData
                    selectedId: root.selectedId
                    cursorId: root.cursorId
                    now: root.now
                    onOpened: id => root.opened(id)
                    onToggled: root.toggled(modelData.id)
                }
            }
        }
    }
}
