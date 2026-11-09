import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.bar.look

// Bar module: the launcher logo (bar.launcherIcon: a glyph or an image
// path, tinted with bar.launcherIconTint); opens / closes the launcher.
BarModuleButton {
    objectName: "launcherButton"
    glyph: Config.bar.launcherIcon || Qt.resolvedUrl("../../../assets/yozakura/yozakura-icon.svg").toString().replace("file://", "")
    tint: Config.bar.launcherIconTint
    imageSize: Config.bar.launcherIconSize
    tooltipText: I18n.t("bar.tooltip.launcher")
    active: GlobalStates.launcherOpen

    onClicked: {
        const open = GlobalStates.launcherOpen;
        GlobalStates.clearLauncherState();
        Visibilities.setActiveModule(open ? "" : "launcher");
    }
}
