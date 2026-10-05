.pragma library

// Display name for an app id when no desktop entry is found:
// "org.gnome.Nautilus" -> "Nautilus", "visual-studio-code" -> "Visual Studio Code".
function pretty(appId) {
    if (!appId)
        return "";
    var parts = String(appId).split(".");
    var last = parts[parts.length - 1];
    return last.split(/[-_ ]+/).filter(function (w) {
        return w.length > 0;
    }).map(function (w) {
        return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(" ");
}
