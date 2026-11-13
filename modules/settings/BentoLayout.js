.pragma library

// The bento of a settings page (SettingsPage): cards of one or two column
// spans packed into `cols` columns, each going where its columns are the
// shortest (masonry, reading order kept as far as the heights allow).
// Pure, node-tested (tests/settings-home.test.cjs).

// Columns for a body width.
function columns(width, minCard) {
    var n = Math.floor(width / Math.max(1, minCard));
    return Math.max(1, Math.min(3, n));
}

// items: [{span, height}] -> [{col, span, y}], the total height and the
// floor (where the shortest column ends), as {places, height, floor}.
// Each card goes to the highest free place that holds it: the shortest
// column, or a hole a wide card left under a shorter one (so no column
// stays empty beside a long one). `gap` between cards in both directions.
// `fixed` (optional, [{col, span}] by item): keep those columns (a card that
// grows or shrinks after the page showed moves down or up in its own
// column, never to another one: nothing reshuffles on a toggle).
function place(items, cols, gap, fixed) {
    var used = [];
    for (var c = 0; c < cols; c++)
        used.push([]);
    function free(col, y, h) {
        var list = used[col];
        for (var i = 0; i < list.length; i++)
            if (y < list[i][1] && list[i][0] < y + h)
                return false;
        return true;
    }
    function lowest(c0, span, h) {
        var ys = [0];
        for (var k = c0; k < c0 + span; k++)
            used[k].forEach(function (r) {
                ys.push(r[1]);
            });
        ys.sort(function (a, b) {
            return a - b;
        });
        for (var i = 0; i < ys.length; i++) {
            var ok = true;
            for (var k = c0; k < c0 + span && ok; k++)
                ok = free(k, ys[i], Math.max(h, 1));
            if (ok)
                return ys[i];
        }
        return ys[ys.length - 1];
    }
    function bottom(col) {
        var end = 0;
        used[col].forEach(function (r) {
            end = Math.max(end, r[1]);
        });
        return end;
    }
    var places = [];
    items.forEach(function (it, n) {
        var span = Math.max(1, Math.min(cols, it.span || 1));
        var h = it.height > 0 ? it.height + gap : 0;
        var best = 0, bestY = Infinity, bestFloor = -Infinity;
        var keep = fixed && fixed[n] && fixed[n].col + span <= cols ? fixed[n].col : -1;
        for (var c = 0; c + span <= cols; c++) {
            if (keep >= 0 && c !== keep)
                continue;
            var y = lowest(c, span, h);
            // among equally high places, the one that lifts the shortest
            // column most (a wide card over an empty column, not beside it)
            var low = Infinity;
            for (var k = 0; k < cols; k++) {
                var end = k >= c && k < c + span ? y + h : bottom(k);
                low = Math.min(low, end);
            }
            if (y < bestY - 0.5 || (Math.abs(y - bestY) <= 0.5 && low > bestFloor + 0.5)) {
                bestY = y;
                best = c;
                bestFloor = low;
            }
        }
        places.push({
            "col": best,
            "span": span,
            "y": bestY
        });
        if (h > 0)
            for (var k = best; k < best + span; k++)
                used[k].push([bestY, bestY + h]);
    });
    var height = 0, floor = Infinity;
    used.forEach(function (list) {
        var end = 0;
        list.forEach(function (r) {
            end = Math.max(end, r[1]);
        });
        height = Math.max(height, end);
        floor = Math.min(floor, end);
    });
    return {
        "places": places,
        "height": Math.max(0, height - gap),
        "floor": Math.max(0, floor - gap)
    };
}

// Editors that need two columns: many pictures a row (more than three
// options), a long timeline or strip, groups side by side, a grid map. Any
// other control (switches, selectors, sliders, a short list, a few
// pictures) fits one column: cards then fill three columns evenly.
var WIDE_EDITORS = ["BarStyleCards", "PanelStyleCards", "PanelShapeCards", "SchemeGallery", "MotionProfileCards", "LockStyleGallery",
    "BarLayoutEditor", "PanelsEditor", "PanelModulesCard", "PanelList", "LayoutBuilder", "IdleTimeline", "PromptStrip",
    "FastfetchEditor", "TerminalLookEditor", "AppThemingEditor", "ShortcutList", "KeybindsOverview", "SpecialsEditor",
    "AiProvidersEditor", "PomodoroEditor", "WallpaperStrip", "SurfaceEffectCards", "IndicatorCards", "NumeralCards",
    "IslandActivitiesEditor", "ActivitiesEditor", "FolderList", "LauncherPrefixList"];

// The span a schema section asks for: `span` when it sets one, else two
// columns when it holds a wide control (WIDE_EDITORS, a picture choice of
// more than three options), one otherwise.
function spanOf(section, inWindow) {
    if (section && section.span)
        return section.span;
    var wide = (section && section.entries || []).some(function (e) {
        if (inWindow && !inWindow(e, section))
            return false;
        if (e.display === "cards")
            return (e.options || []).length > 3;
        // a list of rows that edit text (commands, rules) needs the width
        return e.type === "list" || (e.type === "custom" && WIDE_EDITORS.indexOf(e.component) >= 0);
    });
    return wide ? 2 : 1;
}

// Columns a page uses out of `cols`: never more than its cards fill (one
// narrow card takes one column, centred, never a row of empty ones), and
// two at most unless narrow cards outnumber the wide ones.
function fit(cols, spans) {
    var list = spans || [];
    var narrow = list.filter(function (s) {
        return s < 2;
    }).length;
    var wide = list.length - narrow;
    var total = list.reduce(function (a, s) {
        return a + s;
    }, 0);
    // as many wide cards as narrow ones: two columns (a wide card in three
    // leaves a hole beside it that the few narrow ones cannot fill)
    return Math.max(1, Math.min(narrow > wide ? cols : Math.min(cols, 2), total || cols));
}

// How much room a card's rows take per row: 0 for plain rows (switches,
// short selectors, sliders), 1 for one big control (pictures, an editor, a
// list). Used to order the cards after the lead ones.
function heaviness(section, inWindow) {
    var heavy = (section && section.entries || []).some(function (e) {
        if (inWindow && !inWindow(e, section))
            return false;
        return e.type === "custom" || e.type === "list" || e.type === "multiselect" || e.type === "screens" || e.type === "color-role" || e.display === "cards";
    });
    return heavy ? 1 : 0;
}

// The page order of `sections` (indexes): the card of the tab's master
// switch (`<feature>.enabled`) first, then the cards of plain rows, then
// the ones holding a big control (pictures, an editor, a list), each with
// the lead ids first (as listed), then in schema order. The first screen
// shows the most rows that way, the lead ones at its top.
function order(sections, leadIds, inWindow) {
    var secs = sections || [];
    var lead = (leadIds || []).map(function (id) {
        for (var i = 0; i < secs.length; i++)
            if (secs[i].id === id)
                return i;
        return -1;
    }).filter(function (i) {
        return i >= 0;
    });
    var rest = [];
    for (var i = 0; i < secs.length; i++)
        if (lead.indexOf(i) < 0)
            rest.push(i);
    var all = lead.concat(rest);
    // the tab's master switch (`<feature>.enabled`) heads the page
    var master = -1;
    for (var m = 0; m < secs.length && master < 0; m++)
        if ((secs[m].entries || []).some(function (e) {
            return /^[A-Za-z]+\.enabled$/.test(e.key || "") && (e.type || "toggle") === "toggle" && (!inWindow || inWindow(e, secs[m]));
        }))
            master = m;
    if (master >= 0)
        all = [master].concat(all.filter(function (i) {
            return i !== master;
        }));
    var head = master >= 0 ? [master] : [];
    all = all.filter(function (i) {
        return i !== master;
    });
    var light = all.filter(function (i) {
        return heaviness(secs[i], inWindow) === 0;
    });
    var heavy = all.filter(function (i) {
        return heaviness(secs[i], inWindow) !== 0;
    });
    return head.concat(light, heavy);
}
