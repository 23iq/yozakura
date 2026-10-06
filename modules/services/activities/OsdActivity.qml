pragma Singleton
import QtQuick
import qs.config
import qs.modules.services
import "IslandSources.js" as Sources

// Volume / mic / brightness / output device changes routed into the island
// (OsdService.toIsland, only while notch.osd is on): a level ring with the
// percentage, or the muted state, for about 1.2 s.
EphemeralProvider {
    id: root

    source: "osd"

    Connections {
        target: OsdService
        function onToIsland(kind, value, muted, device) {
            if (Config.notch && Config.notch.osd)
                root.flash(Sources.osdActivity(kind, value, muted, device, {
                    muted: I18n.t("activities.osd.muted")
                }));
        }
    }
}
