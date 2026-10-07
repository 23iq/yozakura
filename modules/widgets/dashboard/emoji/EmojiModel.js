.pragma library

// Pure helpers of the emoji tab (EmojiTab.qml): the emoji table, search,
// the recent list and the variable row geometry of the list. Unit tested in
// tests/emoji-model.test.cjs.

var MAX_RECENT = 50;
var INITIAL = 50;

var SKIN_TONES = [
    { name: "Light", modifier: "\u{1F3FB}" },
    { name: "Medium-Light", modifier: "\u{1F3FC}" },
    { name: "Medium", modifier: "\u{1F3FD}" },
    { name: "Medium-Dark", modifier: "\u{1F3FE}" },
    { name: "Dark", modifier: "\u{1F3FF}" }
];

// assets/emojis.json ({emoji: {name, slug, group, skin_tone_support}}) -> rows.
function parseTable(text) {
    var json;
    try {
        json = JSON.parse(text.trim());
    } catch (e) {
        return [];
    }
    var data = [];
    for (var emoji in json) {
        var info = json[emoji];
        data.push({
            emoji: emoji,
            name: info.name,
            slug: info.slug,
            group: info.group,
            search: info.name + " " + info.slug,
            skin_tone_support: info.skin_tone_support || false
        });
    }
    return data;
}

function parseRecent(text) {
    try {
        var r = JSON.parse(text.trim());
        return Array.isArray(r) ? r : [];
    } catch (e) {
        return [];
    }
}

// Rows matching `query` (the glyph itself, name, slug or group).
function filter(data, query) {
    if (!query)
        return [];
    var q = query.toLowerCase();
    return data.filter(function (e) {
        return e.emoji.indexOf(query) !== -1 || e.search.toLowerCase().indexOf(q) !== -1 || e.group.toLowerCase().indexOf(q) !== -1;
    });
}

function initial(data) {
    return data.slice(0, INITIAL);
}

function skinToneName(modifier) {
    for (var i = 0; i < SKIN_TONES.length; i++) {
        if (SKIN_TONES[i].modifier === modifier)
            return SKIN_TONES[i].name.toLowerCase();
    }
    return "default";
}

// The entry stored in the recent list for `emoji` copied with `modifier`.
function recentEntry(emoji, modifier) {
    var tone = modifier ? skinToneName(modifier) : "";
    return {
        emoji: emoji.emoji + (modifier || ""),
        name: emoji.name + (tone ? " (" + tone + ")" : ""),
        slug: emoji.slug,
        group: emoji.group,
        search: emoji.name + " " + emoji.slug + (tone ? " " + tone : ""),
        skin_tone_support: emoji.skin_tone_support
    };
}

// New recent list with `entry` used once more at `now`: most used first,
// then most recent; at most MAX_RECENT.
function addRecent(recent, entry, now) {
    var old = null;
    var rest = recent.filter(function (r) {
        if (r.emoji === entry.emoji)
            old = r;
        return r.emoji !== entry.emoji;
    });
    var e = Object.assign({}, entry, {
        usage: ((old && old.usage) || entry.usage || 0) + 1,
        lastUsed: now
    });
    rest.unshift(e);
    rest.sort(function (a, b) {
        return (b.usage || 0) !== (a.usage || 0) ? (b.usage || 0) - (a.usage || 0) : (b.lastUsed || 0) - (a.lastUsed || 0);
    });
    return rest.slice(0, MAX_RECENT);
}

// Geometry: `g` = {row, option, recent, expanded} (expanded row index or -1);
// rows are [{recent: bool, tones: bool}].
function rowHeight(rows, i, g) {
    var r = rows[i];
    if (!r)
        return 0;
    if (r.recent)
        return g.recent;
    if (i === g.expanded && r.tones)
        return g.row + SKIN_TONES.length * g.option;
    return g.row;
}

function rowY(rows, index, g) {
    var y = 0;
    for (var i = 0; i < index && i < rows.length; i++)
        y += rowHeight(rows, i, g);
    return y;
}

// contentY that shows [y, y + h] in a viewport, or -1 when already visible.
function scrollToShow(y, h, contentY, viewHeight) {
    if (y < contentY)
        return y;
    if (y + h > contentY + viewHeight)
        return y + h - viewHeight;
    return -1;
}
