import QtQuick
import qs.config
import qs.modules.services
import qs.modules.settings.store
import "ProviderPresets.js" as Presets
import "ProviderConnect.js" as Connect

// Connecting chat providers (Ai.providers): connection state, the Connect
// sheet's test/save/disconnect, and the quiet migration of the old Ollama
// opt-in key. Rules are in ProviderConnect.js; keys stay in the KeyStore,
// local endpoints in ai.ollama.endpoint / ai.lmstudio.endpoint.
QtObject {
    id: root

    property var catalog: null

    readonly property var hidden: Config.ai.providers ? (Config.ai.providers.hidden || []) : []
    // Inputs of ProviderConnect.status(); bindings re-evaluate on key
    // changes, probes and visibility settings.
    readonly property var connectionState: ({
            keys: KeyStore.keyCache,
            ollama: catalog ? catalog.ollama : null,
            lmstudio: catalog ? catalog.lmstudio : null,
            hidden: hidden
        })
    readonly property var listed: {
        const out = {};
        for (const m of (catalog ? catalog.apiModels : []))
            out[m.provider] = true;
        return out;
    }
    readonly property var unconnected: Connect.unconnected(connectionState, listed)
    readonly property bool anyConnected: Presets.ids().some(id => Connect.status(id, connectionState).connected)

    function status(id) {
        return Connect.status(id, connectionState);
    }

    function preset(id) {
        return Presets.preset(id);
    }

    // Values the form starts with for a provider: {key, url, curl}.
    function current(id) {
        const p = Presets.preset(id);
        if (p && p.local)
            return {
                key: "",
                url: Connect.baseUrl(id, id === "ollama" ? Config.ai.ollama.endpoint : (Config.ai.lmstudio ? Config.ai.lmstudio.endpoint : "")),
                curl: ""
            };
        return {
            key: KeyStore.getKey(id) || "",
            url: KeyStore.getEndpoint(id) || (p ? p.baseUrl : ""),
            curl: KeyStore.getCustomCurl(id) || ""
        };
    }

    // cb(summary) with ProviderConnect.summarize()'s shape; never throws.
    function test(id, key, url, cb) {
        const invalid = Connect.validate(id, key, url);
        if (invalid) {
            cb({
                ok: false,
                verified: false,
                count: 0,
                error: I18n.t(invalid),
                models: []
            });
            return;
        }
        const call = Connect.testCall(id, key, url, Connect.headerMap(Connect.extraHeaders(id, Config.ai.providers)));
        BackendService.call(call.method, call.params, (res, err) => cb(Connect.summarize(id, res, err)));
    }

    // Stores a provider's connection and shows it in the picker again.
    function save(id, key, url, curl) {
        if (Connect.validate(id, key, url))
            return false;
        const plan = Connect.savePlan(id, key, url, curl);
        if (plan.keystore)
            KeyStore.setKey(plan.keystore.provider, plan.keystore.key, plan.keystore.endpoint, plan.keystore.curl);
        if (plan.config)
            SettingsStore.set(plan.config.key, plan.config.value);
        if (hidden.indexOf(id) >= 0)
            SettingsStore.set("ai.providers.hidden", hidden.filter(h => h !== id));
        if (plan.config && catalog)
            Qt.callLater(() => root.catalog.probeLocal(true));
        return true;
    }

    // Removes a key; a local provider cannot be "disconnected" while its
    // server runs, so it is hidden from the picker instead.
    function disconnect(id) {
        const p = Presets.preset(id);
        if (p && p.local) {
            if (hidden.indexOf(id) < 0)
                SettingsStore.set("ai.providers.hidden", hidden.concat([id]));
            return;
        }
        KeyStore.deleteKey(id);
    }

    function setHidden(id, hide) {
        const has = hidden.indexOf(id) >= 0;
        if (hide && !has)
            SettingsStore.set("ai.providers.hidden", hidden.concat([id]));
        else if (!hide && has)
            SettingsStore.set("ai.providers.hidden", hidden.filter(h => h !== id));
    }

    // The old "ollama: enabled" KeyStore entry: move its endpoint to the
    // config and delete it (Ollama is detected by probing now).
    function migrate() {
        if (!KeyStore.initialized)
            return;
        const plan = Connect.legacyOllama(KeyStore.keyCache, Config.ai.ollama.endpoint || "");
        if (!plan.remove)
            return;
        if (plan.endpoint)
            SettingsStore.set("ai.ollama.endpoint", plan.endpoint);
        KeyStore.deleteKey("ollama");
    }

    property Connections keys: Connections {
        target: KeyStore
        function onKeysChanged() {
            root.migrate();
        }
    }
    Component.onCompleted: migrate()
}
