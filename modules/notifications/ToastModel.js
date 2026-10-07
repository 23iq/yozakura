.pragma library
.import "../services/activities/NotificationProgress.js" as NotificationProgress

// Pure helpers of the corner toast (CornerToast.qml, ToastCard.qml): which
// notification of a group shows, how deep the stack behind it looks, what
// the caption says, the progress hint and the actions. Unit tested in
// tests/corner-toast-model.test.cjs.

var MAX_STACK = 2;   // sheets peeking out behind a grouped toast

function visible(notifications) {
    return (notifications || []).filter(function (n) {
        return n && (n.summary || n.body);
    });
}

function latest(notifications) {
    var list = visible(notifications);
    if (list.length === 0)
        return null;
    return list.reduce(function (a, b) {
        return b.time > a.time ? b : a;
    });
}

// Sheets drawn behind the card for the rest of the group (0..MAX_STACK).
function stackDepth(count) {
    return Math.max(0, Math.min(MAX_STACK, (count | 0) - 1));
}

// Opacity of the sheet `step` (1 = right behind the card) of the stack:
// clearly there, each one a little quieter (0.85, 0.65).
function sheetOpacity(step) {
    var s = Math.max(1, step | 0);
    return Math.max(0.3, 1.05 - 0.2 * s);
}

// Urgency arrives as the NotificationUrgency enum (Critical = 2) or its
// string form ("2", "critical").
function isCritical(urgency) {
    return urgency === 2 || urgency === "2" || String(urgency).toLowerCase() === "critical";
}

// 0..1 from the standard `value` hint of the live notification, or -1.
function progressOf(n) {
    var hints = n && n.notification ? n.notification.hints : (n ? n.hints : null);
    var v = NotificationProgress.parseValue(hints);
    return v === null ? -1 : v / 100;
}

// "Firefox · 2m", with "+2" for the rest of a group: "Firefox +2 · 2m".
function caption(appName, timeText, extra) {
    var head = String(appName || "");
    if (extra > 0)
        head = head ? head + " +" + extra : "+" + extra;
    var parts = [];
    if (head)
        parts.push(head);
    if (timeText)
        parts.push(timeText);
    return parts.join(" · ");
}

// Actions as {identifier, text}; none on a notification restored from the
// cache (its sender is gone).
function actionsOf(n) {
    if (!n || n.isCached || !n.actions)
        return [];
    var out = [];
    for (var i = 0; i < n.actions.length; i++) {
        var a = n.actions[i];
        if (a && a.text)
            out.push({ "identifier": a.identifier, "text": a.text });
    }
    return out;
}

// Image for the toast's leading art: the notification image (a person or a
// picture, shown round) before the app icon (a rounded square). A named
// icon goes through `resolve` (name -> path, "" when the theme lacks it;
// Quickshell.iconPath(name, true)) so a missing icon falls back to the
// placeholder instead of the theme's "image-missing" picture.
function artOf(n, resolve) {
    if (!n)
        return { "source": "", "round": false };
    var image = n.cachedImage || n.image || "";
    if (image)
        return { "source": toUrl(image), "round": true };
    var icon = n.cachedAppIcon || n.appIcon || "";
    if (!icon)
        return { "source": "", "round": false };
    var named = icon.indexOf("/") !== 0 && icon.indexOf(":") < 0;
    if (!named)
        return { "source": toUrl(icon), "round": false };
    if (typeof resolve !== "function")
        return { "source": "image://icon/" + icon, "round": false };
    var path = resolve(icon) || "";
    return { "source": path ? toUrl(path) : "", "round": false };
}

// The placeholder of the art when there is no picture: the app's initial
// ("" for a critical notification, which shows the alert glyph instead).
function initialOf(n) {
    if (!n || isCritical(n.urgency))
        return "";
    var name = String(n.appName || n.summary || "").trim();
    return name ? name.charAt(0).toUpperCase() : "";
}

// A path becomes a file URL; URLs (file:, data:, image://) stay as they are.
function toUrl(s) {
    return String(s).indexOf("/") === 0 ? "file://" + s : String(s);
}
