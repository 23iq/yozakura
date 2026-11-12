.pragma library

// Pure helpers of the terminal look UI (prompt gallery, live preview):
// styled spans of `term.preview` ({text, fg, bg, bold, italic, underline})
// to drawable runs, column math and the notices. Node-tested
// (tests/term-model.test.cjs).

function _style(s) {
    return {
        "fg": s.fg || "",
        "bg": s.bg || "",
        "bold": !!s.bold,
        "italic": !!s.italic,
        "underline": !!s.underline
    };
}

function _sameStyle(a, b) {
    return a.fg === b.fg && a.bg === b.bg && a.bold === b.bold && a.italic === b.italic && a.underline === b.underline;
}

// Adjacent spans of one style merged into a run; empty spans dropped.
function spansToRuns(spans) {
    var out = [];
    var list = spans || [];
    for (var i = 0; i < list.length; i++) {
        var s = list[i];
        if (!s || !s.text)
            continue;
        var st = _style(s);
        var last = out.length > 0 ? out[out.length - 1] : null;
        if (last && _sameStyle(last, st)) {
            last.text += s.text;
        } else {
            st.text = String(s.text);
            out.push(st);
        }
    }
    return out;
}

// Terminal columns of a span list (one per code point: Nerd Font Mono
// glyphs are single-width).
function columns(spans) {
    var n = 0;
    var list = spans || [];
    for (var i = 0; i < list.length; i++)
        n += Array.from(String(list[i].text || "")).length;
    return n;
}

// Columns between the last left line and the right prompt on a `cols`
// wide terminal; -1 when the right prompt does not fit (fish hides it).
function alignRight(left, right, cols) {
    var gap = cols - columns(left) - columns(right);
    return gap >= 1 ? gap : -1;
}

// Runs placed on whole pixels: x and width come from the rounded running
// advance, so neighbouring backgrounds always touch. measure(text, bold,
// italic) -> advance in px.
function layoutRuns(runs, measure) {
    var out = [];
    var acc = 0;
    var x = 0;
    for (var i = 0; i < runs.length; i++) {
        var r = runs[i];
        acc += measure(r.text, r.bold, r.italic);
        var end = Math.round(acc);
        out.push(Object.assign({}, r, {
            "x": x,
            "width": end - x
        }));
        x = end;
    }
    return out;
}

// The first candidate family that is installed (case-insensitive match
// against Qt.fontFamilies()), else "monospace".
function pickFont(candidates, families) {
    var have = {};
    var fams = families || [];
    for (var i = 0; i < fams.length; i++)
        have[String(fams[i]).toLowerCase()] = fams[i];
    var list = candidates || [];
    for (var j = 0; j < list.length; j++) {
        var c = String(list[j] || "").trim();
        if (c !== "" && have[c.toLowerCase()] !== undefined)
            return have[c.toLowerCase()];
    }
    return "monospace";
}

// Some installed family carries the Nerd Font icons ("Symbols Nerd Font",
// "JetBrainsMono Nerd Font", ...).
function hasNerdFont(families) {
    var fams = families || [];
    for (var i = 0; i < fams.length; i++) {
        if (/nerd/i.test(String(fams[i])))
            return true;
    }
    return false;
}

function previewKey(engine, id) {
    return engine + ":" + id;
}

// Apps & Extras catalog id of an engine.
function engineExtra(engine) {
    return engine === "ohmyposh" ? "oh-my-posh" : "starship";
}

var _REASONS = ["engine_missing", "git_missing", "timeout"];

// Why a preview is approximate ({reason: i18n key, install: extras id or
// ""}); null when it is exact or unknown yet.
function approxNotice(preview) {
    if (!preview || preview.exact !== false)
        return null;
    var reason = _REASONS.indexOf(preview.reason) >= 0 ? preview.reason : "error";
    return {
        "reason": "prefs.term.look.approx." + reason,
        "install": reason === "engine_missing" ? engineExtra(preview.engine) : ""
    };
}

// "unknown" (no status yet), "missing", "notLogin" or "ok".
function fishState(status) {
    if (!status)
        return "unknown";
    if (!status.fishInstalled)
        return "missing";
    return status.fishIsLoginShell ? "ok" : "notLogin";
}

// Block elements (U+2580..U+259F half and quadrant blocks, fastfetch logos)
// are drawn as boxes like kitty draws them, not with the font's glyphs,
// which leave seams between cells. The boxes of one character as
// [x0, y0, x1, y1] fractions of its cell; null for any other character.
// Quadrant bits: 1 upper left, 2 upper right, 4 lower left, 8 lower right.
var _QUADS = {
    "\u2580": 3,
    "\u2584": 12,
    "\u2588": 15,
    "\u258c": 5,
    "\u2590": 10,
    "\u2596": 4,
    "\u2597": 8,
    "\u2598": 1,
    "\u2599": 13,
    "\u259a": 9,
    "\u259b": 7,
    "\u259c": 11,
    "\u259d": 2,
    "\u259e": 6,
    "\u259f": 14
};

function blockBoxes(ch) {
    var q = _QUADS[ch];
    if (q === undefined)
        return null;
    var out = [];
    var cells = [[0, 0, 0.5, 0.5], [0.5, 0, 1, 0.5], [0, 0.5, 0.5, 1], [0.5, 0.5, 1, 1]];
    for (var i = 0; i < 4; i++) {
        if (q & (1 << i))
            out.push(cells[i]);
    }
    return out;
}

// The text has a block element (drawn cell by cell).
function hasBlocks(text) {
    var chars = Array.from(String(text || ""));
    for (var i = 0; i < chars.length; i++) {
        if (_QUADS[chars[i]] !== undefined)
            return true;
    }
    return false;
}
