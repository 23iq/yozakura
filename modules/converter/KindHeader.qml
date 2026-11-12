import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// Over two or more files of one kind: "Images · 3" and a chip that sets
// the target of all of them at once (their shared target, or "Mixed").
Item {
    id: root

    required property var converter
    required property string kind
    readonly property var group: root.converter.groups.find(g => g.kind === root.kind) || null
    // a converting or converted row keeps its target: no chip once none can change
    readonly property bool editable: root.converter.rows.some(r => r.kind === root.kind && Model.editable(r))

    signal pickKind(string kind, Item anchor)

    implicitHeight: Space.chip + Space.s
    implicitWidth: label.implicitWidth + chip.implicitWidth + Look.rowInset * 2

    SectionLabel {
        id: label
        anchors.left: parent.left
        anchors.right: chip.left
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t(Model.kindInfo(root.kind).label) + " · " + (root.group ? root.group.count : 0)
    }

    Chip {
        id: chip
        objectName: "kindChip"
        visible: root.editable
        anchors.right: parent.right
        anchors.rightMargin: Look.rowInset + Space.controlS + Space.s
        anchors.verticalCenter: parent.verticalCenter
        dense: true
        quiet: true
        focusable: true
        icon: Icons.swap
        text: root.group && root.group.target !== "" ? I18n.t("converter.all_to", root.group.target.toUpperCase()) : I18n.t("converter.all_mixed")
        trailingIcon: Icons.caretDown
        onClicked: root.pickKind(root.kind, chip)
    }
}
