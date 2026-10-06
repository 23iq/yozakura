.pragma library

// Dashboard tabs. The index of a tab here is its stable index
// (GlobalStates.dashboardCurrentTab, global shortcuts); `layout.dashboard.tabs`
// only sets the rail order and visibility.
var tabs = [
    { id: "widgets", icon: "widgets", labelKey: "dashboard.tab.widgets" },
    { id: "wallpapers", icon: "wallpapers", labelKey: "dashboard.tab.wallpapers" },
    { id: "metrics", icon: "heartbeat", labelKey: "dashboard.tab.metrics" }
];

function ids() {
    return tabs.map(function (t) { return t.id; });
}

function indexOf(id) {
    return ids().indexOf(id);
}

// Config list -> every known tab once, in config order; unknown ids are
// dropped and missing ones appended (visible).
function resolve(list) {
    var out = [];
    var seen = {};
    var src = Array.isArray(list) ? list : [];
    for (var i = 0; i < src.length; i++) {
        var t = src[i];
        if (!t || typeof t !== "object" || indexOf(t.id) < 0 || seen[t.id])
            continue;
        seen[t.id] = true;
        out.push({ id: t.id, visible: t.visible !== false });
    }
    ids().forEach(function (id) {
        if (!seen[id])
            out.push({ id: id, visible: true });
    });
    return out;
}

// Stable indices of the visible tabs in rail order (never empty).
function visibleIndices(list) {
    var out = resolve(list).filter(function (t) { return t.visible; }).map(function (t) { return indexOf(t.id); });
    return out.length > 0 ? out : [0];
}

function move(list, id, delta) {
    var out = resolve(list);
    var i = out.findIndex(function (t) { return t.id === id; });
    var j = i + delta;
    if (i < 0 || j < 0 || j >= out.length)
        return out;
    var item = out.splice(i, 1)[0];
    out.splice(j, 0, item);
    return out;
}

function setVisible(list, id, on) {
    return resolve(list).map(function (t) {
        return t.id === id ? { id: t.id, visible: !!on } : t;
    });
}

// Next stable index from `current` in rail `order`; wraps unless wrap is false.
function step(order, current, delta, wrap) {
    var pos = order.indexOf(current);
    if (pos < 0)
        return order[0];
    var next = pos + delta;
    if (wrap === false)
        return order[Math.max(0, Math.min(order.length - 1, next))];
    return order[((next % order.length) + order.length) % order.length];
}
