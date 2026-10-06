pragma Singleton
import QtQuick
import qs.config
import qs.modules.services
import "IslandSources.js" as Sources
import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry

// Installs and removals queued in the extras catalog (ExtrasService jobs)
// as percent transfers: they join the downloads segment and the transfers
// panel. Off with the island's "extras" activity.
ActivityProvider {
    id: root

    source: "extras"

    readonly property bool live: root.active && Registry.isEnabled(Config.notch ? Config.notch.activities : [], "extras")
    readonly property var entries: ExtrasService.catalog && ExtrasService.catalog.entries ? ExtrasService.catalog.entries : []

    function nameOf(id) {
        const e = root.entries.find(x => x && x.id === id);
        return e && e.name ? e.name : id;
    }

    transfers: root.live ? Sources.extrasTransfers(ExtrasService.jobs, id => root.nameOf(id), 0) : []
}
