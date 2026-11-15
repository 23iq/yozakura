import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The header of one kind's rows: "Images · 3" and, over two or more files
// that can still change, a chip that sets the target of all of them at
// once (their shared target, or "All to..."). It ends with the rows' empty
// action slot, so its chip lines up with the target chips under it.
Item {
    id: root

    required property var converter
    required property string kind
    readonly property var group: root.converter.groups.find(g => g.kind === root.kind) || null
    // a converting or converted row keeps its target: no chip once none can change
    readonly property bool editable: root.converter.rows.some(r => r.kind === root.kind && Model.editable(r))

    signal pickKind(string kind, Item anchor)

    implicitHeight: Space.chip + Space.s
    implicitWidth: layout.implicitWidth + Look.rowInset

    // the rows' geometry: the ListRow's right inset, the trailing spacing
    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.rightMargin: Look.rowInset
        spacing: Space.s

        SectionLabel {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: I18n.t(Model.kindInfo(root.kind).label) + " · " + (root.group ? root.group.count : 0)
        }

        Chip {
            id: chip
            objectName: "kindChip"
            Layout.alignment: Qt.AlignVCenter
            // the target chips' width: the same column, edge to edge
            Layout.preferredWidth: Math.max(chip.implicitWidth, Space.controlXL)
            visible: root.editable && root.group !== null && root.group.count > 1
            dense: true
            focusable: true
            action: true
            icon: Icons.swap
            text: root.group && root.group.target !== "" ? I18n.t("converter.all_to", root.group.target.toUpperCase()) : I18n.t("converter.all_mixed")
            trailingIcon: Icons.caretDown
            onClicked: root.pickKind(root.kind, chip)
        }

        ActionSlot {
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
