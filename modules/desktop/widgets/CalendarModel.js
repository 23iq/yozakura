.pragma library

// Month grid and calendar event parsing for the calendar widget. Pure;
// tests/desktop-widgets.test.cjs.

// 6x7 cells of the month containing `date`, weeks starting on `firstDay`
// (0 = Sunday, 1 = Monday). Cell: {day, month (0-11), year, inMonth, today}.
function monthGrid(date, firstDay, today) {
    var y = date.getFullYear();
    var m = date.getMonth();
    var first = new Date(y, m, 1);
    var lead = (first.getDay() - firstDay + 7) % 7;
    var start = new Date(y, m, 1 - lead);
    var t = today || new Date();
    var cells = [];
    for (var i = 0; i < 42; i++) {
        var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
        cells.push({
            day: d.getDate(),
            month: d.getMonth(),
            year: d.getFullYear(),
            inMonth: d.getMonth() === m,
            today: d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate()
        });
    }
    return cells;
}

// Rows actually needed (5 or 6, 4 for a February starting on firstDay).
function rowsNeeded(date, firstDay) {
    var y = date.getFullYear();
    var m = date.getMonth();
    var lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
    var days = new Date(y, m + 1, 0).getDate();
    return Math.ceil((lead + days) / 7);
}

// weekStart option ("locale" | "monday" | "sunday") -> 0..6.
function firstDayOf(weekStart, localeFirstDay) {
    if (weekStart === "monday")
        return 1;
    if (weekStart === "sunday")
        return 0;
    var f = Number(localeFirstDay);
    return isFinite(f) ? f % 7 : 1;
}

// Weekday indexes (0 = Sunday) in display order.
function weekdayOrder(firstDay) {
    var out = [];
    for (var i = 0; i < 7; i++)
        out.push((firstDay + i) % 7);
    return out;
}

// Output of
//   khal list today 14d --day-format "" \
//       --format "{start-date}<TAB>{start-time}<TAB>{title}"
// -> [{date, time, title}] in khal's order (chronological), at most
// `limit`. Dates stay in the user's khal format (shown as they are); an
// all-day event has an empty time.
function parseKhal(text, limit) {
    var out = [];
    String(text || "").split("\n").forEach(function (line) {
        var parts = line.split("\t");
        if (parts.length < 3)
            return;
        var date = parts[0].trim();
        var title = parts.slice(2).join(" ").trim();
        if (date === "" || title === "")
            return;
        var time = parts[1].trim();
        out.push({
            date: date,
            time: /^\d{1,2}[:.]\d{2}/.test(time) ? time : "",
            title: title
        });
    });
    return limit > 0 ? out.slice(0, limit) : out;
}
