.pragma library
.import "ProviderPresets.js" as Presets

// Connection rules of the chat providers (pure, node-tested): what
// "connected" means per provider, the Connect sheet's validation, test call
// and result summary, request headers from the provider settings and the
// migration of the old Ollama opt-in key.
//
// `state` given to status():
//   keys      KeyStore cache {provider: {api_key, endpoint, custom_curl}}
//   ollama    last probe {reachable, endpoint, error}
//   lmstudio  last listing {reachable, endpoint, error}
//   hidden    provider ids hidden from the picker (ai.providers.hidden)

var LOCAL_KEYS = { ollama: "ai.ollama.endpoint", lmstudio: "ai.lmstudio.endpoint" };

function _entry(keys, id) {
    return (keys || {})[id] || null;
}

// Base URL of a provider: the configured one (local endpoint setting or the
// KeyStore endpoint) or the preset default.
function baseUrl(id, configured) {
    var p = Presets.preset(id);
    var c = String(configured || "").trim();
    return c || (p ? p.baseUrl : "");
}

// {state: "connected" | "offline" | "none" | "hidden", connected, local}
//   offline: a local provider that is set up but not reachable right now.
function status(id, state) {
    var s = state || {};
    var p = Presets.preset(id);
    var local = !!(p && p.local);
    if ((s.hidden || []).indexOf(id) >= 0)
        return { state: "hidden", connected: false, local: local };
    var connected;
    if (local) {
        var probe = s[id] || {};
        connected = !!probe.reachable;
        return { state: connected ? "connected" : (probe.endpoint && probe.error ? "offline" : "none"), connected: connected, local: true };
    }
    var e = _entry(s.keys, id);
    if (id === "custom")
        connected = !!(e && e.endpoint);
    else
        connected = !!(e && e.api_key);
    return { state: connected ? "connected" : "none", connected: connected, local: false };
}

// Providers to list as "not connected" in the picker: presets that are
// neither connected, hidden, nor already listing models.
function unconnected(state, listed) {
    var l = listed || {};
    return Presets.sorted().filter(function (p) {
        if (l[p.id])
            return false;
        var st = status(p.id, state).state;
        return st === "none" || st === "offline";
    }).map(function (p) {
        return { id: p.id, label: p.label, icon: p.icon };
    });
}

function _validUrl(u) {
    return /^https?:\/\/[^\s/]+/.test(u);
}

// "" when the form can be tested/saved, else an i18n key.
function validate(id, key, url) {
    var p = Presets.preset(id);
    var u = String(url || "").trim();
    if (p && p.keyRequired && !String(key || "").trim())
        return "ai.connect.need_key";
    if (id === "custom" && !u)
        return "ai.connect.need_url";
    if (u && !_validUrl(u))
        return "ai.connect.bad_url";
    return "";
}

// Backend call that tests a form: {method, params}. Ollama is probed
// (models with capabilities); everything else is a free listing.
function testCall(id, key, url, headers) {
    var u = String(url || "").trim();
    if (id === "ollama")
        return { method: "providers.ollama.probe", params: { endpoint: u } };
    var params = { provider: id, baseUrl: u, key: String(key || "").trim() };
    if (headers && Object.keys(headers).length > 0)
        params.headers = headers;
    return { method: "providers.test", params: params };
}

// Normalised result of testCall(): {ok, verified, count, error, models}.
// Ollama models keep their capability record (`probe`) for the badges.
function summarize(id, res, err) {
    if (err || !res)
        return { ok: false, verified: false, count: 0, error: String(err ? (err.message || err) : "no response"), models: [] };
    if (id === "ollama") {
        var list = (res.models || []).filter(function (m) {
            var caps = m.capabilities || [];
            return caps.indexOf("embedding") < 0 || caps.indexOf("completion") >= 0;
        });
        return { ok: !!res.reachable, verified: !!res.reachable, count: list.length, error: res.reachable ? "" : (res.error || "unreachable"), version: res.version || "", models: list.map(function (m) {
                return { id: m.id, name: m.name || m.id, probe: m };
            }) };
    }
    var models = res.models || [];
    return { ok: !!res.ok, verified: res.verified !== false && !!res.ok, count: models.length, error: res.ok ? "" : (res.error || "failed"), models: models };
}

// What save() writes: {keystore: {provider, key, endpoint, curl} | null,
// config: {key, value} | null}. Local providers store their endpoint in
// the config (it is not a secret); `defaultUrl` is not stored.
function savePlan(id, key, url, curl) {
    var p = Presets.preset(id);
    var u = String(url || "").trim().replace(/\/+$/, "");
    if (p && p.local)
        return { keystore: null, config: { key: LOCAL_KEYS[id], value: u === p.baseUrl ? "" : u } };
    var endpoint = p && p.editableUrl ? u : (u && p && u !== p.baseUrl ? u : "");
    return { keystore: { provider: id, key: String(key || "").trim(), endpoint: endpoint, curl: id === "custom" ? String(curl || "") : "" }, config: null };
}

// The old opt-in for Ollama was a fake "enabled" KeyStore key. Returns
// {remove, endpoint}: delete the entry and, when it carried an endpoint
// and none is configured yet, move it to ai.ollama.endpoint.
function legacyOllama(keys, configuredEndpoint) {
    var e = _entry(keys, "ollama");
    if (!e)
        return { remove: false, endpoint: "" };
    var ep = String(e.endpoint || "").trim();
    return { remove: true, endpoint: ep && !configuredEndpoint ? ep : "" };
}

function _clean(s) {
    return String(s === undefined || s === null ? "" : s).replace(/[\r\n]+/g, " ").trim();
}

// Extra request headers ["Name: value"] for a provider from the
// ai.providers settings: custom headers for the Custom endpoint and the
// optional OpenRouter app attribution (`app`: {url, name}, from Brand).
function extraHeaders(id, cfg, app) {
    var c = cfg || {};
    var out = [];
    if (id === "custom") {
        var list = c.customHeaders || [];
        for (var i = 0; i < list.length; i++) {
            var name = _clean(list[i] && list[i].name).replace(/[:\s]/g, "");
            if (name)
                out.push(name + ": " + _clean(list[i].value));
        }
    } else if (id === "openrouter" && c.openrouterAttribution !== false && app) {
        if (app.url)
            out.push("HTTP-Referer: " + _clean(app.url));
        if (app.name)
            out.push("X-Title: " + _clean(app.name));
    }
    return out;
}

// ["Name: value"] -> {Name: value} (providers.test `headers`).
function headerMap(lines) {
    var out = {};
    (lines || []).forEach(function (l) {
        var i = l.indexOf(":");
        if (i > 0)
            out[l.substring(0, i).trim()] = l.substring(i + 1).trim();
    });
    return out;
}

// Presets shown in the Connect sheet grid (remote, local, custom).
function presets() {
    return Presets.sorted();
}
