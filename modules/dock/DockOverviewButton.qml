import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The dock's overview button: niri's own overview, the shell's elsewhere
// (on the dock's screen).
IconButton {
    id: root

    required property ShellScreen screen

    size: "s"
    icon: Icons.overview
    tooltip: I18n.t("bar.tooltip.overview")
    onClicked: {
        if (YozdService.compositorName === "niri") {
            YozdService.dispatch("overview toggle");
            return;
        }
        const visibilities = Visibilities.getForScreen(root.screen.name);
        if (visibilities)
            visibilities.overview = !visibilities.overview;
    }
}
