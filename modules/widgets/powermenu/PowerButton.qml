import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.look

// Bar module: opens / closes the power menu (accent while it is open).
BarModuleButton {
    id: powerButton
    objectName: "powerButton"

    readonly property bool open: Visibilities.currentActiveModule === "powermenu"

    glyph: Icons.shutdown
    tooltipText: I18n.t("bar.tooltip.powermenu")
    active: powerButton.open
    onClicked: Visibilities.setActiveModule(powerButton.open ? "" : "powermenu")
}
