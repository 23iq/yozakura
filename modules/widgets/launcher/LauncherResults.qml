import QtQuick
import qs.config
import "Providers.js" as Providers
import "../../components/preview/Preview.js" as Preview
// Makes providers/ reachable for Quickshell's scanner (loaded by URL).
import "providers"

// Runs the launcher providers (Providers.js, one component per provider)
// for the search text and merges their results in the configured order.
// `items` is the flat list the view shows: each result gets `provider`
// (id) added. Providers answer synchronously or later (files); every change
// re-merges on the next tick.
//
// Preview (`preview`, a PreviewContext; Settings' launcher stage): only the
// providers named in the sample "launcher.live" are created and searched
// (the apps: in memory, so the stage lists your real apps); every other
// provider shows its sample rows, "launcher.rows" ({providerId: [rows]}),
// in the configured order. Nothing runs (activate is inert).
QtObject {
    id: host

    property var preview: null
    readonly property var liveIds: Preview.sample(host.preview, "launcher.live", [])
    readonly property var sampleRows: Preview.sample(host.preview, "launcher.rows", ({}))

    property string text: ""
    property string mode: "empty"
    property var items: []
    property var providers: ({})
    readonly property var order: Config.prefix.launcher.order
    readonly property var disabled: Config.prefix.launcher.disabled
    readonly property bool busy: {
        const ids = Object.keys(providers);
        for (let i = 0; i < ids.length; i++) {
            if (providers[ids[i]].busy)
                return true;
        }
        return false;
    }
    property var _route: ({
            "mode": "empty",
            "providers": []
        })
    property bool _pending: false

    // LauncherSearch wires these.
    signal closeRequested
    signal searchRequested(string text)

    function prefixFor(id) {
        const p = Providers.byId(id);
        return p && p.prefix ? (Config.prefix[p.prefix] || "") : "";
    }

    function prefixes() {
        const out = {};
        Providers.PROVIDERS.forEach(p => {
            if (p.prefix)
                out[p.prefix] = Config.prefix[p.prefix] || "";
        });
        return out;
    }

    function setSearch(t) {
        host.searchRequested(t);
    }

    function close() {
        host.closeRequested();
    }

    function provider(id) {
        return host.providers[id] || null;
    }

    function _create() {
        const made = {};
        Providers.PROVIDERS.forEach(p => {
            if (p.kind !== "inline")
                return;
            if (Preview.on(host.preview) && host.liveIds.indexOf(p.id) === -1)
                return;
            const comp = Qt.createComponent(Qt.resolvedUrl(p.file));
            if (comp.status !== Component.Ready) {
                console.warn("launcher: provider", p.id, comp.errorString());
                return;
            }
            const obj = comp.createObject(host, {
                "providerId": p.id,
                "host": host
            });
            if (!obj)
                return;
            obj.resultsChanged.connect(host._schedule);
            made[p.id] = obj;
        });
        host.providers = made;
        host.refresh();
    }

    function search(t) {
        host.text = t;
        host._route = Providers.route(t, host.prefixes(), host.order, host.disabled);
        host.mode = host._route.mode;
        const wanted = {};
        host._route.providers.forEach(r => wanted[r.id] = r.query);
        Object.keys(host.providers).forEach(id => {
            const p = host.providers[id];
            if (wanted.hasOwnProperty(id))
                p.search(wanted[id], host.mode);
            else
                p.clear();
        });
        host._schedule();
    }

    function refresh() {
        host.search(host.text);
    }

    function _schedule() {
        if (host._pending)
            return;
        host._pending = true;
        Qt.callLater(host._merge);
    }

    function _merge() {
        host._pending = false;
        const out = [];
        const mixed = host.mode === "mixed";
        host._route.providers.forEach(r => {
            const p = host.providers[r.id];
            const sample = Preview.on(host.preview) ? host.sampleRows[r.id] : null;
            if (!p && !sample)
                return;
            let rows = p ? (p.results || []) : sample;
            if (mixed && p && p.mixedLimit > 0)
                rows = rows.slice(0, p.mixedLimit);
            rows.forEach(row => out.push(Object.assign({
                    "provider": r.id
                }, row)));
        });
        host.items = out;
    }

    // The provider of an item and the action for it.
    function activate(item, option) {
        if (Preview.on(host.preview))
            return false;
        const p = item ? host.providers[item.provider] : null;
        return p ? p.activate(item, option || "") : false;
    }

    function options(item) {
        const p = item ? host.providers[item.provider] : null;
        return p ? p.options(item) : [];
    }

    function completion(item) {
        const p = item ? host.providers[item.provider] : null;
        return p ? p.completion(item) : "";
    }

    // Tab / "?": hand the raw query to the AI provider.
    function askAi() {
        if (Preview.on(host.preview))
            return false;
        const p = host.providers["ai"];
        if (!p || !Providers.isEnabled("ai", host.disabled))
            return false;
        const pre = host.prefixFor("ai");
        const q = Providers.stripPrefix(host.text, pre);
        return p.ask(q !== null ? q : host.text);
    }

    onOrderChanged: refresh()
    onDisabledChanged: refresh()
    onSampleRowsChanged: if (Preview.on(host.preview))
        host._schedule()
    Component.onCompleted: _create()
}
