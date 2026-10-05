.pragma library

// Clock text helpers: a copy of modules/desktop/clockstyles/ClockText.js
// (the greeter cannot read the shell tree).

var KANJI_DIGITS = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
var KANJI_WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];

function kanjiNumber(n) {
    n = Math.floor(n);
    if (n < 10)
        return KANJI_DIGITS[n];
    var tens = Math.floor(n / 10);
    var ones = n % 10;
    return (tens > 1 ? KANJI_DIGITS[tens] : "") + "十" + (ones > 0 ? KANJI_DIGITS[ones] : "");
}

function kanjiDate(date) {
    return kanjiNumber(date.getMonth() + 1) + "月" + kanjiNumber(date.getDate()) + "日";
}

function kanjiWeekday(date) {
    return KANJI_WEEKDAYS[date.getDay()] + "曜日";
}

function kanjiMeridiem(date) {
    return date.getHours() < 12 ? "午前" : "午後";
}

function hours(date, use12h) {
    var h = date.getHours();
    if (use12h)
        return String(((h + 11) % 12) + 1);
    return (h < 10 ? "0" : "") + h;
}

function minutes(date) {
    var m = date.getMinutes();
    return (m < 10 ? "0" : "") + m;
}

function chars(text) {
    return Array.from(String(text));
}
