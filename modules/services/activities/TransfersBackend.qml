pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.services.activities
import "ActivityModel.js" as Model

// Bridge to the backend "transfers" service (backend/pkg/svc/transfers):
// tells it which sources to run (only those whose provider is active) and
// splits its item stream per source for the TransferProvider singletons.
Singleton {
    id: root

    readonly property var settings: Model.normalizeConfig(Config.notch ? Config.notch.liveActivities : undefined)

    // Sources the backend should run: every registered backend-backed
    // provider that is enabled
    readonly property var wanted: {
        const out = {};
        for (const p of ActivityProviders.all)
            if (p.backendSource)
                out[p.source] = p.active;
        return out;
    }
    readonly property bool anyWanted: Object.keys(wanted).some(k => wanted[k])

    readonly property var options: ({
            endpoints: root.settings.downloads.endpoints,
            secrets: root.settings.downloads.secrets
        })

    property var items: []
    readonly property var itemsBySource: {
        const out = {};
        for (const it of items) {
            if (!out[it.source])
                out[it.source] = [];
            out[it.source].push(it);
        }
        return out;
    }

    property var subscription: null

    function configure() {
        if (!BackendService.connected && !root.anyWanted)
            return;
        BackendService.call("transfers.configure", {
            sources: root.wanted,
            options: root.options
        }, () => {});
    }

    onWantedChanged: configureTimer.restart()
    onOptionsChanged: configureTimer.restart()
    onAnyWantedChanged: {
        if (anyWanted && subscription === null) {
            subscription = BackendService.addSubscription(["transfers"], (service, data) => {
                if (service !== "transfers.state" || !data)
                    return;
                const list = data.items || [];
                Qt.callLater(() => {
                    root.items = list;
                });
            });
        } else if (!anyWanted && subscription !== null) {
            BackendService.removeSubscription(subscription);
            subscription = null;
            items = [];
        }
    }

    Connections {
        target: BackendService
        function onConnectedChanged() {
            if (BackendService.connected)
                configureTimer.restart();
        }
    }

    // Coalesce config edits into one call
    Timer {
        id: configureTimer
        interval: 200
        onTriggered: root.configure()
    }

    Component.onCompleted: {
        anyWantedChanged();
        configureTimer.restart();
    }

    function action(transfer, name) {
        BackendService.call("transfers.action", {
            id: transfer.id,
            action: name
        }, () => {});
    }
}
