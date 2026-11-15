.pragma library

// Live previews of real shell parts (settings stages, picture cards). A
// part rendered as a preview gets a PreviewContext (`preview`, null in the
// live shell) and reads the config keys a picture may show with another
// value through `pick`:
//
//     readonly property string indicatorStyle:
//         Preview.pick(bar ? bar.preview : null, "workspaces.indicatorStyle",
//                      Config.workspaces.indicatorStyle)
//
// `live` is the live config value, read in the caller's binding so the
// binding keeps following the config; an override in the context wins.
// Tests: tests/live-preview.test.cjs.

// on(ctx) -> true when the part is a preview (no popups, no reveal logic,
// nothing session-wide)
function on(ctx) {
    return ctx !== null && ctx !== undefined;
}

// pick(ctx, key, live) -> the context's override of `key`, else `live`
function pick(ctx, key, live) {
    if (!ctx)
        return live;
    var o = ctx.overrides;
    if (o && Object.prototype.hasOwnProperty.call(o, key))
        return o[key];
    return live;
}

// sample(ctx, name, live) -> the context's sample `name` (data a preview
// shows instead of a live service's: a track, notifications, activities;
// a sample that is null or [] means "none"), else `live`. Read the live
// value in the caller's binding, like `pick`:
//
//     readonly property var player: Preview.sample(preview, "player",
//                                                  MprisController.activePlayer)
//
// The sample names a part reads are listed where it reads them (the
// island: modules/notch/AGENTS.md, SETTINGS PREVIEWS).
function sample(ctx, name, live) {
    if (!ctx)
        return live;
    var s = ctx.samples;
    if (s && Object.prototype.hasOwnProperty.call(s, name))
        return s[name];
    return live;
}

// withValue(overrides, key, value) -> a copy of `overrides` with `key` set
// (a picture card of one option: the stage's overrides plus its value)
function withValue(overrides, key, value) {
    var out = {};
    var src = overrides || {};
    for (var k in src)
        out[k] = src[k];
    out[key] = value;
    return out;
}
