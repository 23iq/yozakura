import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "ModsModel.js" as ModsModel

// One installed mod: drag handle (load-order view), state dot, name,
// version and state, Enable/Disable. Selecting shows its details.
StyledRect {
    id: row

    required property var mod
    property bool current: false
    property bool dropTarget: false
    property bool reorderable: false
    // Item the drag handle moves (the list's floating preview).
    property Item dragTarget: null
    readonly property bool dragging: reorderDrag.active

    signal selected
    signal toggleRequested
    signal dragStarted
    signal dragFinished

    readonly property string stateText: I18n.t(ModsModel.stateKey(row.mod))

    implicitHeight: Metrics.rowHeight + 6
    variant: row.current ? "primary" : (rowMouse.containsMouse || activeFocus ? "focus" : "common")
    radius: Styling.radius(0)
    enableShadow: false
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: (row.mod.name ?? row.mod.id) + ", " + row.stateText
    Accessible.onPressAction: row.selected()

    Keys.onReturnPressed: row.selected()
    Keys.onEnterPressed: row.selected()
    Keys.onSpacePressed: row.selected()

    StyledRect {
        anchors.fill: parent
        visible: row.dropTarget
        variant: "focus"
        radius: row.radius
        enableShadow: false
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            row.forceActiveFocus();
            row.selected();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacing + 4
        anchors.rightMargin: Metrics.spacing
        spacing: Metrics.spacing + 2

        Text {
            visible: row.reorderable
            text: Icons.dotsNine
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(3)
            color: row.item
            opacity: reorderDrag.active ? 1 : 0.6
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t("mods.drag_order")

            DragHandler {
                id: reorderDrag
                target: row.dragTarget
                xAxis.enabled: false
                enabled: row.reorderable && !ModsService.busy
                onActiveChanged: active ? row.dragStarted() : row.dragFinished()
            }
        }

        // Status dot: the state reads before any text does.
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: Colors[ModsModel.stateTone(row.mod)]
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: row.mod.name ?? row.mod.id
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: row.item
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (row.mod.version || I18n.t("mods.unknown_version")) + " · " + row.stateText
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: row.item
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        PillButton {
            kind: row.mod.enabled ? "ghost" : "filled"
            text: row.mod.enabled ? I18n.t("mods.disable") : I18n.t("mods.enable")
            enabled: !ModsService.busy && ModsModel.canToggle(row.mod, ModsService.bypassVersionCheck)
            onClicked: row.toggleRequested()
        }
    }
}
