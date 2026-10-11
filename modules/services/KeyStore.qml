pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Cache of loaded keys: { "openai": { api_key: "...", endpoint: "", custom_curl: "" }, ... }
    property var keyCache: ({})
    property bool initialized: false

    // Last write failure ("" when the last write succeeded).
    property string lastError: ""

    signal keysChanged

    Component.onCompleted: {
        refreshKeys();
    }

    function refreshKeys() {
        BackendService.call("keystore.list", {}, (result, error) => {
            if (error || !result || !Array.isArray(result)) return;
            let cache = {};
            for (let i = 0; i < result.length; i++) {
                const k = result[i];
                cache[k.provider] = {
                    api_key: k.api_key || "",
                    endpoint: k.endpoint || "",
                    custom_curl: k.custom_curl || ""
                };
            }
            root.keyCache = cache;
            root.initialized = true;
            root.keysChanged();
        });
    }

    function getKey(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.api_key : "";
    }

    function getEndpoint(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.endpoint : "";
    }

    function getCustomCurl(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.custom_curl : "";
    }

    function hasKey(provider) {
        return keyCache[provider] !== undefined && keyCache[provider].api_key !== "";
    }

    function _errorText(result, error) {
        if (error)
            return typeof error === "string" ? error : (error.message || String(error));
        if (!result)
            return "no reply";
        return result.error ? String(result.error) : "";
    }

    // done(errorText) is called with "" on success.
    function setKey(provider, apiKey, endpoint, customCurl, done) {
        BackendService.call("keystore.set", {
            provider: provider,
            api_key: apiKey,
            endpoint: endpoint || "",
            custom_curl: customCurl || ""
        }, (result, error) => {
            const msg = root._errorText(result, error);
            root.lastError = msg;
            if (msg) {
                console.warn("KeyStore: Failed to set key:", msg);
            } else {
                root.refreshKeys();
            }
            if (done)
                done(msg);
        });
    }

    function deleteKey(provider, done) {
        BackendService.call("keystore.delete", {
            provider: provider
        }, (result, error) => {
            const msg = root._errorText(result, error);
            root.lastError = msg;
            if (msg) {
                console.warn("KeyStore: Failed to delete key:", msg);
            } else {
                root.refreshKeys();
            }
            if (done)
                done(msg);
        });
    }
}
