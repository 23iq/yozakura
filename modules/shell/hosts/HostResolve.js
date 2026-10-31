.pragma library
.import "SurfaceRegistry.js" as Registry

// Pure host resolution (node-tested in tests/host-resolve.test.cjs).
// resolve(layout, surface, ctx) -> the host that shows `surface`:
//   layout  Config.layout (plain or JsonObject)
//   ctx     {notchEnabled, barEnabled, barEdges}; a missing ctx or
//           notchEnabled counts as an enabled notch
// An explicit host is kept while it is available; "auto", an unknown value
// or an unavailable host (an explicit "notch" with the notch off) walk the
// surface's auto chain. Runtime only: the config is never rewritten.

function _value(layout, key) {
    var parts = key.split(".");
    var v = layout;
    for (var i = 0; i < parts.length; i++) {
        if (v === null || v === undefined)
            return undefined;
        v = v[parts[i]];
    }
    return v;
}

// Whether `host` can show anything under ctx. barEnabled/barEdges are for
// bar-anchored hosts (none yet).
function available(host, ctx) {
    var h = Registry.host(host);
    if (!h)
        return false;
    if (h.needsNotch && ctx && ctx.notchEnabled === false)
        return false;
    return true;
}

// The host that stands in for one not built yet.
function _built(host) {
    var h = Registry.host(host);
    return h && h.built === false && h.standIn ? h.standIn : host;
}

// The configured value of `surface` ("auto" when unset or unknown).
function chosen(layout, surface) {
    var s = Registry.surface(surface);
    if (!s)
        return "auto";
    var v = _value(layout, s.key);
    return s.allowed.indexOf(v) !== -1 ? v : "auto";
}

function resolve(layout, surface, ctx) {
    var s = Registry.surface(surface);
    if (!s)
        return "";
    var c = chosen(layout, surface);
    var chain = c === "auto" ? s.auto : [c].concat(s.auto);
    for (var i = 0; i < chain.length; i++) {
        if (available(chain[i], ctx))
            return _built(chain[i]);
    }
    return _built(s.auto[s.auto.length - 1]);
}

// A layout holding only `value` for `surface` (a settings row's value).
function layoutWith(surface, value) {
    var s = Registry.surface(surface);
    if (!s)
        return null;
    var parts = s.key.split(".");
    var out = {};
    var at = out;
    for (var i = 0; i < parts.length - 1; i++) {
        at[parts[i]] = {};
        at = at[parts[i]];
    }
    at[parts[parts.length - 1]] = value;
    return out;
}

// The host `surface` is shown in instead of the chosen one because the
// notch is off ("" when it shows where chosen, or "auto" picks the notch).
function shownInstead(layout, surface, ctx) {
    if (!ctx || ctx.notchEnabled !== false)
        return "";
    var c = chosen(layout, surface);
    var r = resolve(layout, surface, ctx);
    return r !== c ? r : "";
}
