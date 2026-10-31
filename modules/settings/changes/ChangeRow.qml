pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One changed setting on the Changes page: its name, "now · was" values,
// a reset (to the default, or to the preset's value) and a jump to the row
// on its page (the whole row is clickable too).
ListRow {
    id: root

    property var change
    // "%1 · default %2" style string: %1 = now, %2 = default / preset value
    property string valuesKey: "prefs.changes.vs_default"
    readonly property bool canJump: !!(change && change.categoryId)

    signal resetRequested
    signal jumpRequested

    objectName: "changeRow:" + (change ? change.id : "")
    title: change ? change.label : ""
    subtitle: change && change.now !== "" ? I18n.t(root.valuesKey, change.now, change.was) : ""
    onClicked: if (root.canJump)
        root.jumpRequested()

    trailing: Component {
        Row {
            spacing: Space.xs

            IconButton {
                objectName: "changeReset"
                size: "s"
                icon: Icons.arrowCounterClockwise
                onClicked: root.resetRequested()
                Accessible.name: I18n.t("common.reset_default")
            }
            IconButton {
                objectName: "changeJump"
                size: "s"
                visible: root.canJump
                icon: Icons.caretRight
                onClicked: root.jumpRequested()
                Accessible.name: I18n.t("prefs.changes.open")
            }
        }
    }
}
