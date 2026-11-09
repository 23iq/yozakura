import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The dock's pin toggle: keeps the dock shown (`pinned`, accent while on).
IconButton {
    id: root

    property bool pinned: false

    signal toggled

    size: "s"
    active: root.pinned
    icon: root.pinned ? Icons.pin : Icons.unpin
    tooltip: root.pinned ? I18n.t("dock.tooltip.unpin_dock") : I18n.t("dock.tooltip.pin_dock")
    onClicked: root.toggled()
}
