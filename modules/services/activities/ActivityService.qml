pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services.activities
import qs.modules.services
import qs.modules.theme
import qs.config
import "ActivityModel.js" as Model
import "TransferModel.js" as Transfers

// Aggregates every registered provider (ActivityProviders.qml) into:
//   activities  sorted, de-duplicated live activities (ActivityModel.js
//               shape); transfers become one "downloads" activity (or one
//               per transfer when downloads.aggregate is off)
//   tasks       activities with category "task" (timers, downloads)
//   privacy     activities with category "privacy" (recording, mic...)
//   transfers   de-duplicated transfers for detailed views (TransferModel.js)
// Presentation (bar.activities.presentation): "notch" renders them inside
// the notch (modules/widgets/defaultview/activities), "islands" next to it
// (modules/bar/activities), "off" disables every provider. With the notch
// off they move to the bar or the corner pills (ShellLayout, "corner").
Singleton {
    id: root

    readonly property var settings: Model.normalizeConfig(Config.bar ? Config.bar.activities : undefined)
    readonly property bool isEnabled: settings.enabled && settings.presentation !== "off"
    readonly property string presentation: isEnabled ? ShellLayout.activityPresentation(settings.presentation) : "off"
    readonly property int maxVisible: settings.maxVisible
    readonly property bool showSpeed: settings.downloads.showSpeed

    readonly property var transfersAll: {
        if (!isEnabled)
            return [];
        let all = [];
        for (const p of ActivityProviders.all)
            if (p.active && p.transfers.length > 0)
                all = all.concat(p.transfers);
        return Transfers.dedupe(all);
    }

    readonly property var aggregated: isEnabled ? Model.aggregate(ActivityProviders.all.map(p => ({
                source: p.source,
                activities: p.active ? p.activities : []
            })).concat([
        {
            source: "downloads",
            activities: Transfers.toActivities(root.transfersAll, {
                aggregate: root.settings.downloads.aggregate,
                icon: Icons.downloadSimple,
                priority: Model.PRIORITY.downloads,
                title: I18n.t("activities.downloads")
            }).map(a => Object.assign(a, {
                    image: root.iconUrl(a.image)
                }))
        }
    ])) : []

    // Re-published only when something visible changed, so per-second
    // updates of unrelated fields do not churn the delegates
    property var activities: []
    property var transfers: []
    readonly property int count: activities.length
    readonly property var tasks: activities.filter(a => a.category === "task")
    readonly property var privacy: activities.filter(a => a.category === "privacy")

    onAggregatedChanged: {
        if (Model.signature(aggregated) !== Model.signature(activities))
            activities = aggregated;
    }
    onTransfersAllChanged: {
        if (JSON.stringify(transfersAll) !== JSON.stringify(transfers))
            transfers = transfersAll;
    }
    Component.onCompleted: {
        activities = aggregated;
        transfers = transfersAll;
    }

    // Icon theme name, absolute path or URL -> URL ("" stays "")
    function iconUrl(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.indexOf("://") !== -1 || icon.startsWith("data:") || icon.startsWith("image:"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    function providerFor(source) {
        return ActivityProviders.all.find(p => p.source === source) || null;
    }

    function transferById(id) {
        return root.transfers.find(t => t.id === id) || null;
    }

    function activate(activity, button, screenName) {
        if (!activity)
            return;
        if (activity.source === "downloads") {
            // A single download opens directly; several are listed in the
            // expanded view
            const t = activity.action ? root.transferById(activity.action) : (root.transfers.length === 1 ? root.transfers[0] : null);
            if (t)
                root.transferAction(t, "open");
            return;
        }
        const provider = root.providerFor(activity.source);
        if (provider)
            provider.activate(activity, button, screenName);
    }

    // "open": provider-specific opener, the transfer's URL, or its folder
    // (file selected through org.freedesktop.FileManager1 when possible);
    // anything else goes to the provider (cancel/suspend/resume)
    function transferAction(transfer, action) {
        const provider = root.providerFor(transfer.source);
        if (action !== "open") {
            if (provider)
                provider.transferAction(transfer, action);
            return;
        }
        if (provider && typeof provider.openTransfer === "function") {
            provider.openTransfer(transfer);
            return;
        }
        if (transfer.openUrl) {
            Qt.openUrlExternally(transfer.openUrl);
            return;
        }
        const path = transfer.path || "";
        const dir = transfer.dir || (path ? path.substring(0, path.lastIndexOf("/")) : "");
        if (path)
            Quickshell.execDetached(["sh", "-c", "dbus-send --session --print-reply --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:\"file://$1\" string:\"\" >/dev/null 2>&1 || xdg-open \"$2\"", "sh", path, dir || path]);
        else if (dir)
            Quickshell.execDetached(["xdg-open", dir]);
    }
}
