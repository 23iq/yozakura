.pragma library

// Bar clock faces behind a registry (bar.moduleOptions.clock.face). Each
// face is a small QML file under faces/ loaded by ClockFace.qml. A vertical
// bar turns `digital` into `stacked` (the other faces are kept). Pure
// functions, tested by tests/clock-faces.test.cjs.
var faces = [
    { id: "digital", url: "faces/Digital.qml", labelKey: "prefs.bar.clock_face.digital" },
    { id: "stacked", url: "faces/Stacked.qml", labelKey: "prefs.bar.clock_face.stacked" },
    { id: "dotMatrix", url: "faces/DotMatrix.qml", labelKey: "prefs.bar.clock_face.dotMatrix" },
    { id: "kanji", url: "faces/Kanji.qml", labelKey: "prefs.bar.clock_face.kanji" }
];

function ids() {
    return faces.map(function (f) { return f.id; });
}

function byId(id) {
    for (var i = 0; i < faces.length; i++)
        if (faces[i].id === id)
            return faces[i];
    return null;
}

function resolve(face, vertical) {
    var f = byId(face) || faces[0];
    if (vertical && f.id === "digital")
        return byId("stacked");
    return f;
}

var KANJI_DIGITS = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"];

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

// hours/minutes strings: 24h zero-padded, 12h 1..12 with an AM/PM suffix.
function parts(h, m, use12h) {
    return {
        "hours": use12h ? String(((h + 11) % 12) + 1) : pad2(h),
        "minutes": pad2(m),
        "suffix": use12h ? (h < 12 ? "AM" : "PM") : ""
    };
}

// 0..99 in kanji: 5 → 五, 10 → 十, 11 → 十一, 25 → 二十五. Zero is 零 (the
// spoken numeral, not the 〇 placeholder digit) and is always shown, so the
// face keeps its rhythm on the hour: 十時 零分.
function kanjiNumeral(n) {
    n = Math.floor(n);
    if (n < 10)
        return KANJI_DIGITS[n];
    var tens = Math.floor(n / 10);
    var ones = n % 10;
    return (tens > 1 ? KANJI_DIGITS[tens] : "") + "十" + (ones > 0 ? KANJI_DIGITS[ones] : "");
}

function kanjiMinutes(m) {
    return kanjiNumeral(m) + "分";
}

// 十時 二十五分; 12h: 午後 一時 三十分.
function kanjiTime(h, m, use12h) {
    var hour = use12h ? ((h + 11) % 12) + 1 : h;
    var text = kanjiNumeral(hour) + "時 " + kanjiMinutes(m);
    return use12h ? (h < 12 ? "午前 " : "午後 ") + text : text;
}

// Weekday in kanji (0 = Sunday): 日曜日 .. 土曜日 (the wide clock panel's
// quiet accent).
function kanjiWeekday(day) {
    return "日月火水木金土".charAt(((Math.floor(day) % 7) + 7) % 7) + "曜日";
}
