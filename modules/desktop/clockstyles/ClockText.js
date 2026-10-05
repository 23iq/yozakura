.pragma library

// Text helpers shared by the desktop clock styles. Pure functions (no Qt
// APIs) so they can be unit-tested with node (tests/clock-styles.test.cjs).

var KANJI_DIGITS = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
// Date.getDay() order: Sunday first.
var KANJI_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

// 1..99 in kanji: 5 → 五, 10 → 十, 11 → 十一, 20 → 二十, 31 → 三十一.
function kanjiNumber(n) {
    n = Math.floor(n);
    if (n < 10)
        return KANJI_DIGITS[n];
    var tens = Math.floor(n / 10);
    var ones = n % 10;
    return (tens > 1 ? KANJI_DIGITS[tens] : "") + "十" + (ones > 0 ? KANJI_DIGITS[ones] : "");
}

// 十月五日
function kanjiDate(date) {
    return kanjiNumber(date.getMonth() + 1) + "月" + kanjiNumber(date.getDate()) + "日";
}

// 月曜日
function kanjiWeekday(date) {
    return KANJI_WEEKDAYS[date.getDay()] + "曜日";
}

// 午前 / 午後
function kanjiMeridiem(date) {
    return date.getHours() < 12 ? "午前" : "午後";
}

function meridiem(date) {
    return date.getHours() < 12 ? "AM" : "PM";
}

// 24h: zero-padded ("09"). 12h: 1..12, unpadded ("9"), like a spoken time.
function hours(date, use12h) {
    var h = date.getHours();
    if (use12h)
        return String(((h + 11) % 12) + 1);
    return pad2(h);
}

function minutes(date) {
    return pad2(date.getMinutes());
}

// Split a string into single characters (code points) for vertical columns.
function chars(text) {
    return Array.from(String(text));
}
