pragma Singleton
import QtQuick
import qs.config
import qs.modules.services
import "IslandSources.js" as Sources

// Volume / mic / brightness / output device changes routed into the island
// (OsdService.toIsland, only with the OSD style "island"): a level ring with the
// percentage, or the muted state, for about 1.2 s.
EphemeralProvider {
    id: root

    source: "osd"

    // The island renders routed levels, so the OSD window can stay hidden.
    Component.onCompleted: OsdService.islandHandled = true

    Connections {
        target: OsdService
        function onToIsland(kind, value, muted, device) {
            if (OsdService.style === "island")
                root.flash(Sources.osdActivity(kind, value, muted, device, {
                    muted: I18n.t("activities.osd.muted")
                }));
        }
    }
}
