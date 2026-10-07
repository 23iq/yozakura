pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look
import qs.modules.theme
import qs.modules.globals

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size, and "flat" (no group box of its own)
    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false

    // Popup visibility state (tracks intent, not animation)
    property bool popupOpen: layoutPopup.isOpen

    objectName: "layoutSelectorModule"

    Layout.preferredWidth: root.moduleSize
    Layout.preferredHeight: root.moduleSize
    Layout.maximumWidth: root.moduleSize
    Layout.maximumHeight: root.moduleSize
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    function getLayoutIcon(layout) {
        switch (layout) {
        case "dwindle":
            return Icons.dwindle;
        case "master":
            return Icons.master;
        case "scrolling":
            return Icons.scrolling;
        case "monocle":
            return Icons.monocle;
        default:
            return Icons.dwindle;
        }
    }

    function getLayoutDisplayName(layout) {
        switch (layout) {
        case "dwindle":
            return "Dwindle";
        case "master":
            return "Master";
        case "scrolling":
            return "Scrolling";
        case "monocle":
            return "Monocle";
        default:
            return layout;
        }
    }

    Item {
        id: buttonBg
        anchors.fill: parent

        ModuleBox {
            id: box
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
            flat: root.flat
            shadow: root.layerEnabled
            active: root.popupOpen
            hovered: root.isHovered
        }

        Text {
            anchors.centerIn: parent
            text: root.getLayoutIcon(GlobalStates.compositorLayout)
            font.family: Icons.font
            font.pixelSize: BarLook.iconSize(root.moduleSize)
            color: box.ink
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: layoutPopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: I18n.t("bar.tooltip.layout", root.getLayoutDisplayName(GlobalStates.compositorLayout))
        }
    }

    // Layout popup: one kit row per compositor layout, the current one selected
    BarPopup {
        id: layoutPopup
        objectName: "layoutPopup"
        anchorItem: buttonBg
        bar: root.bar
        popupPadding: Look.surfacePadding

        contentWidth: 220 + popupPadding * 2
        contentHeight: layoutColumn.implicitHeight + popupPadding * 2

        Column {
            id: layoutColumn
            width: parent.width
            spacing: Space.xs

            Repeater {
                model: GlobalStates.availableLayouts

                delegate: ListRow {
                    id: layoutRow
                    required property string modelData

                    width: layoutColumn.width
                    implicitHeight: Space.controlM
                    title: root.getLayoutDisplayName(layoutRow.modelData)
                    selected: GlobalStates.compositorLayout === layoutRow.modelData
                    leading: Text {
                        text: root.getLayoutIcon(layoutRow.modelData)
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("body")
                        color: layoutRow.selected ? Type.accent : Type.secondary
                    }
                    onClicked: GlobalStates.setCompositorLayout(layoutRow.modelData)
                }
            }
        }
    }
}
