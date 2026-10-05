import QtQuick
import qs.modules.services
import qs.modules.theme

// Connectivity and power values shared by every style's status strip.
QtObject {
    readonly property string networkIcon: {
        if (NetworkService.ethernet)
            return Icons.ethernet;
        if (!NetworkService.wifiEnabled || NetworkService.wifiStatus === "disabled")
            return Icons.wifiOff;
        if ((NetworkService.networkName ?? "") === "")
            return Icons.wifiX;
        return NetworkService.wifiIconForStrength(NetworkService.networkStrength);
    }
    readonly property string networkLabel: NetworkService.ethernet ? I18n.t("lockscreen.wired") : (NetworkService.networkName ?? "")
    readonly property bool batteryAvailable: Battery.available
    readonly property string batteryIcon: Battery.getBatteryIcon()
    readonly property int batteryPercent: Math.round(Battery.percentage)
    readonly property bool batteryLow: Battery.percentage <= 15 && !Battery.isPluggedIn
}
