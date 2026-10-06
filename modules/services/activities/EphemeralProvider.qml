import QtQuick
import qs.config
import qs.modules.theme
import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry

// Base of the island's ephemeral activities (osd, battery, bluetooth): one
// activity with a fixed id that `flash()` shows for the registry's
// ephemeralMs. A new flash while it is visible updates the same item and
// restarts the timer, so the segment never blinks or re-measures; it only
// leaves when the timer ends.
ActivityProvider {
    id: provider

    // Registry id (ActivityRegistry.js); also the provider's source
    property string registryId: source
    readonly property bool registryEnabled: Registry.isEnabled(Config.notch ? Config.notch.activities : [], provider.registryId)
    readonly property bool live: provider.active && provider.registryEnabled
    readonly property int ephemeralMs: {
        const d = Registry.descriptor(provider.registryId);
        return d ? d.ephemeralMs : 2000;
    }

    // a: IslandSources.js activity whose `icon` is an Icons property name
    function flash(a) {
        if (!provider.live || !a)
            return;
        provider.activities = [Object.assign({}, a, {
                icon: Icons[a.icon] || "",
                startedAt: provider.activities.length ? provider.activities[0].startedAt : Date.now()
            })];
        expiry.restart();
    }

    function clear() {
        expiry.stop();
        provider.activities = [];
    }

    onLiveChanged: if (!live)
        clear()

    property Timer expiry: Timer {
        interval: provider.ephemeralMs
        onTriggered: provider.activities = []
    }
}
