.pragma library

// notifications.notchStyle registry: "card" (NotchNotificationCard, the
// full notification) or "compact" (CompactNotification, one line that
// expands on hover). Unknown values fall back to card.

var STYLES = ["card", "compact"];

function resolve(style) {
    return STYLES.indexOf(style) !== -1 ? style : "card";
}

function isCompact(style) {
    return resolve(style) === "compact";
}
