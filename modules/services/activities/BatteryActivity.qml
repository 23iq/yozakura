pragma Singleton
import QtQuick
import qs.modules.services
import "IslandSources.js" as Sources

// Charging started, or the battery fell to the low threshold: a short
// ring with the percentage in the island.
EphemeralProvider {
    id: root

    source: "battery"

    readonly property var sample: ({
            available: Battery.available,
            percent: Math.round(Battery.percentage),
            charging: Battery.isCharging
        })
    property var _last: null

    onSampleChanged: {
        const evt = Sources.batteryEvent(root._last, root.sample, Sources.LOW_BATTERY);
        root._last = root.sample;
        if (evt)
            root.flash(Sources.batteryActivity(evt, {
                low: I18n.t("activities.battery.low"),
                charging: I18n.t("activities.battery.charging")
            }));
    }
    Component.onCompleted: root._last = root.sample
}
