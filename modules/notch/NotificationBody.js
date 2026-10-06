.pragma library

// Text helpers of notifications in the notch. Unit tested in
// tests/notch-notification-styles.test.cjs.

var CHROMIUM = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

// Chromium-family browsers prefix the body with a link to the site:
// drop that first paragraph. Line breaks are kept.
function clean(body, appName) {
    if (!body)
        return "";
    if (appName) {
        var app = String(appName).toLowerCase();
        var isChromium = CHROMIUM.some(function (n) {
            return app.indexOf(n) !== -1;
        });
        if (isChromium) {
            var parts = String(body).split("\n\n");
            if (parts.length > 1 && parts[0].indexOf("<a") === 0)
                return parts.slice(1).join("\n\n");
        }
    }
    return String(body);
}

// One-line text of a compact row: "Summary · body" with whitespace folded.
function oneLine(summary, body, appName) {
    var s = String(summary || "").replace(/\s+/g, " ").trim();
    var b = clean(body, appName).replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    if (s && b)
        return s + " · " + b;
    return s || b;
}
