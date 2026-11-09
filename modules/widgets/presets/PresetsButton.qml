import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.bar.look

// Bar module: opens / closes the presets gallery (accent while it is open).
BarModuleButton {
    glyph: Icons.magicWand
    tooltipText: I18n.t("bar.tooltip.presets")
    active: GlobalStates.presetsOpen
    onClicked: Visibilities.setActiveModule(GlobalStates.presetsOpen ? "" : "presets")
}
