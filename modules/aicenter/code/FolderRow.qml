pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
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
    radius: Styling.radius(-6)
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

    Text {
        visible: root.header
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: root.header ? I18n.t("ai.folder.section_" + root.row.label) : ""
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-4)
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Colors.outline
    }

    RowLayout {
        visible: !root.header
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10
        Text {
            text: root.row.git ? Icons.gitBranch : (root.row.type === "recent" ? Icons.clockCounterClockwise : Icons.folder)
            font.family: Icons.font
            font.pixelSize: BarLook.font(-1)
            color: root.row.git ? Colors.primary : Colors.outline
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: root.row.name || ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                font.weight: root.row.git ? Font.DemiBold : Font.Normal
                color: Colors.overSurface
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.row.detail
                text: root.row.detail || ""
                elide: Text.ElideMiddle
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.mono(-4)
                color: Colors.outline
            }
        }
        Text {
            visible: root.current
            text: Icons.caretRight
            font.family: Icons.font
            font.pixelSize: BarLook.font(-4)
            color: Colors.outline
        }
    }
}
