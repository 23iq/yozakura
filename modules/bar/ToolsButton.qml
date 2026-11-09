import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.look

// Bar module: opens / closes the tools menu (accent while it is open).
BarModuleButton {
    id: toolsButton
    objectName: "toolsButton"

    readonly property bool open: Visibilities.currentActiveModule === "tools"

    glyph: Icons.toolbox
    tooltipText: I18n.t("bar.tooltip.tools")
    active: toolsButton.open
    onClicked: Visibilities.setActiveModule(toolsButton.open ? "" : "tools")
}
