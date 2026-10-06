.pragma library

// What a line typed in the notch quick input means before it reaches the
// backend parser (timers.parse / timers.quick):
//   ""                      -> {kind: "empty"}
//   "focus" / "focus 50"    -> {kind: "focus", minutes}  (FocusMode)
//   "note buy milk"         -> {kind: "note", text}      (QuickNote)
//   anything in note mode   -> {kind: "note", text}
//   everything else         -> {kind: "timers", text}    (backend)
// Tested in tests/timers-quick-input.test.cjs.

var FOCUS_WORDS = ["focus", "фокус", "foco", "enfoque"];
var NOTE_WORDS = ["note", "заметка", "nota"];

// Minutes of a short length: "50", "50m", "1h", "1h30", "1.5h", "90 min".
// Returns 0 when it does not parse.
function minutesOf(spec) {
    var s = String(spec || "").trim().toLowerCase().replace(/\s+/g, "");
    if (s === "")
        return 0;
    var m = /^(\d+(?:[.,]\d+)?)(m|min|mins|minutes|м|мин)?$/.exec(s);
    if (m)
        return Math.round(parseFloat(m[1].replace(",", ".")));
    m = /^(\d+(?:[.,]\d+)?)(h|hr|hrs|hours|ч)(\d+)?(m|min|м|мин)?$/.exec(s);
    if (m)
        return Math.round(parseFloat(m[1].replace(",", ".")) * 60) + (m[3] ? parseInt(m[3], 10) : 0);
    return 0;
}

function classify(text, mode) {
    var raw = String(text || "");
    var t = raw.trim();
    if (t === "")
        return {
            "kind": "empty"
        };
    if (mode === "note")
        return {
            "kind": "note",
            "text": t
        };
    var words = t.split(/\s+/);
    var head = words[0].toLowerCase();
    if (FOCUS_WORDS.indexOf(head) !== -1) {
        var rest = words.slice(1).join(" ");
        var minutes = minutesOf(rest);
        return {
            "kind": "focus",
            "minutes": minutes,
            "valid": rest === "" || minutes > 0
        };
    }
    if (NOTE_WORDS.indexOf(head) !== -1 && words.length > 1)
        return {
            "kind": "note",
            "text": t.substring(words[0].length).trim()
        };
    return {
        "kind": "timers",
        "text": t
    };
}
