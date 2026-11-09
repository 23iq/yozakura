pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// One row of the folder picker: a section header ("Recent", "Repositories",
// "Folders") or a folder. Click browses into it, double click (or Enter on
// the selected row) chooses it. Git repositories are highlighted.
StyledRect {
    id: root

    property var row: ({})
    property bool current: false
    signal browse
    signal choose
    signal hovered

    readonly property bool header: row.type === "header"
    objectName: header ? "folderHeader_" + row.label : "folderRow_" + row.name
    implicitHeight: header ? 26 : (row.detail ? 44 : 34)
    radius: Look.radius("small")
    variant: header ? "transparent" : (current ? "focus" : (hover.hovered ? "common" : "transparent"))

    HoverHandler {
        id: hover
        enabled: !root.header
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered)
            root.hovered()
    }
    TapHandler {
        enabled: !root.header
        onSingleTapped: root.browse()
        onDoubleTapped: root.choose()
    }

    AiText {
        role: "caption"
        visible: root.header
        anchors.left: parent.left
        anchors.leftMargin: Space.s
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.xs
        text: root.header ? I18n.t("ai.folder.section_" + root.row.label) : ""
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    RowLayout {
        visible: !root.header
        anchors.fill: parent
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.s
        Icon {
            role: "secondary"
            icon: root.row.git ? Icons.gitBranch : (root.row.type === "recent" ? Icons.clockCounterClockwise : Icons.folder)
            size: BarLook.size("secondary")
            color: root.row.git ? Colors.primary : Colors.outline
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: root.row.name || ""
                elide: Text.ElideRight
                font.weight: root.row.git ? Font.DemiBold : Font.Normal
                color: Type.text
            }
            AiText {
                mono: true
                role: "caption"
                Layout.fillWidth: true
                visible: !!root.row.detail
                text: root.row.detail || ""
                elide: Text.ElideMiddle
            }
        }
        Icon {
            role: "caption"
            tone: "muted"
            visible: root.current
            icon: Icons.caretRight
            size: BarLook.size("caption")
        }
    }
}
