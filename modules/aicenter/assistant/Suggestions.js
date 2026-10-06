.pragma library

// Contextual suggestion chips for the Assistant empty state.
//
// suggest(ctx, kinds, max) -> [{id, kind, icon, text, args, context}]
//   ctx:   {hour, clipboard: {text, isImage}, media: {title, artist, playing},
//           window: {appId, title}, timer: {label, remaining}}
//          (every part optional; missing parts produce no chip)
//   kinds: enabled kinds (ai.behavior.suggestionKinds); empty/undefined = all
//   text:  translation key; args fill %1, %2 (I18n.t(text).arg(...))
//   context: what the composer attaches on click ("" | clipboard | selection | region)

var KINDS = ["clipboard", "selection", "media", "timer", "window", "desktop", "time"];

var ERROR_RE = /(Traceback \(most recent call last\)|Exception|panic: |error(\[E\d+\])?:|Segmentation fault|\bat .+:\d+)/;
var URL_RE = /^https?:\/\/\S+$/;
var CODE_RE = /(\bfunction\b|\bdef \w+\(|=>|;\s*$|^\s*(import|#include|package|const|let|var|class)\b|[{}]\s*$)/m;

function _clip(text, n) {
    var s = String(text || "").replace(/\s+/g, " ").trim();
    return s.length > n ? s.substring(0, n - 1) + "…" : s;
}

function _clipboard(c) {
    if (!c)
        return [];
    if (c.isImage)
        return [{ id: "clip-image", kind: "clipboard", icon: "image", text: "ai.sug_clip_image", args: [], context: "clipboard" }];
    var t = String(c.text || "").trim();
    if (!t)
        return [];
    if (ERROR_RE.test(t))
        return [{ id: "clip-error", kind: "clipboard", icon: "bug", text: "ai.sug_clip_error", args: [], context: "clipboard" }];
    if (URL_RE.test(t))
        return [{ id: "clip-url", kind: "clipboard", icon: "link", text: "ai.sug_clip_url", args: [], context: "clipboard" }];
    if (CODE_RE.test(t) && t.indexOf("\n") >= 0)
        return [{ id: "clip-code", kind: "clipboard", icon: "code", text: "ai.sug_clip_code", args: [], context: "clipboard" }];
    if (t.length > 280)
        return [{ id: "clip-long", kind: "clipboard", icon: "clipboardText", text: "ai.sug_clip_summarize", args: [], context: "clipboard" }];
    return [{ id: "clip-text", kind: "clipboard", icon: "clipboardText", text: "ai.sug_clip_explain", args: [], context: "clipboard" }];
}

function _media(m) {
    if (!m || !m.title)
        return [];
    var label = m.artist ? m.title + " · " + m.artist : m.title;
    return [{ id: m.playing ? "media-playing" : "media-paused", kind: "media", icon: "musicNotes", text: m.playing ? "ai.sug_media_similar" : "ai.sug_media_about", args: [_clip(label, 48)], context: "" }];
}

function _timer(t) {
    if (!t || !t.label)
        return [];
    return [{ id: "timer", kind: "timer", icon: "timer", text: "ai.sug_timer_left", args: [_clip(t.label, 32)], context: "" }];
}

function _window(w) {
    var app = w && (w.appId || w.title);
    if (!app)
        return [];
    return [{ id: "window", kind: "window", icon: "appWindow", text: "ai.sug_window_help", args: [_clip(w.appId || w.title, 28)], context: "" }];
}

function _time(hour) {
    if (hour === undefined || hour === null)
        return [];
    if (hour >= 5 && hour < 12)
        return [{ id: "time-morning", kind: "time", icon: "sun", text: "ai.sug_plan_day", args: [], context: "" }];
    if (hour >= 22 || hour < 5)
        return [{ id: "time-night", kind: "time", icon: "moon", text: "ai.sug_night_light", args: [], context: "" }];
    return [{ id: "time-focus", kind: "time", icon: "timer", text: "ai.sug_focus", args: [], context: "" }];
}

var SELECTION = [{ id: "selection", kind: "selection", icon: "cursorText", text: "ai.sug_summarize_selection", args: [], context: "selection" },
    { id: "region", kind: "selection", icon: "selection", text: "ai.sug_region", args: [], context: "region" }];

var DESKTOP = [{ id: "desktop-theme", kind: "desktop", icon: "palette", text: "ai.sug_light", args: [], context: "" },
    { id: "desktop-dnd", kind: "desktop", icon: "bellSlash", text: "ai.sug_dnd", args: [], context: "" },
    { id: "desktop-wallpaper", kind: "desktop", icon: "wallpapers", text: "ai.sug_wallpaper", args: [], context: "" }];

function suggest(ctx, kinds, max) {
    var c = ctx || {};
    var on = kinds && kinds.length ? kinds : KINDS;
    var limit = max > 0 ? max : 4;
    // Live context first (it is what the user is looking at), then the
    // always-available prompts.
    var all = [].concat(_clipboard(c.clipboard), _media(c.media), _timer(c.timer), _window(c.window), SELECTION.slice(0, 1), _time(c.hour), DESKTOP.slice(0, 1), SELECTION.slice(1), DESKTOP.slice(1));
    var out = [];
    for (var i = 0; i < all.length && out.length < limit; i++)
        if (on.indexOf(all[i].kind) >= 0)
            out.push(all[i]);
    return out;
}
