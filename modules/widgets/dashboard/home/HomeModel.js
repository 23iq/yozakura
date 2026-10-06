.pragma library

// Pure helpers of the composed dashboard home (tests/dashboard-home-model.test.cjs).

// Seconds -> "m:ss" (or "h:mm:ss").
function formatTime(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var mm = h > 0 && m < 10 ? "0" + m : "" + m;
    return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec;
}

// "artist · album", skipping the empty parts.
function artistLine(artist, album) {
    return [artist, album].filter(function (s) {
        return s && String(s).trim() !== "";
    }).join(" · ");
}

// Notification text (may hold markup) -> one plain line.
function plainLine(text) {
    return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
}

// Name of the first connected device of BluetoothService.friendlyDeviceList.
function connectedDevice(list) {
    var l = list || [];
    for (var i = 0; i < l.length; i++) {
        if (l[i] && l[i].connected)
            return l[i].name || "";
    }
    return "";
}

// One notification group -> the row it shows: {title, body, app, icon,
// image}. A group of several shows the app name and "latest · N more"
// (`more` formats the count).
function groupRow(group, more) {
    var list = group && group.notifications ? group.notifications : [];
    var latest = list.length > 0 ? list[list.length - 1] : null;
    if (!latest)
        return { title: group ? group.appName || "" : "", body: "", app: "", icon: "", image: "" };
    var many = list.length > 1;
    var line = plainLine(many ? (latest.summary || latest.body) : latest.body);
    return {
        title: many || !latest.summary ? (group.appName || latest.appName || "") : plainLine(latest.summary),
        body: many ? (line !== "" ? line + " · " : "") + more(list.length - 1) : line,
        app: latest.appName || group.appName || "",
        icon: latest.cachedAppIcon || latest.appIcon || "",
        image: latest.cachedImage || latest.image || ""
    };
}

// Image source of a row's avatar: the notification image, else the app icon
// from the icon theme, else none (the Avatar shows the app's initials).
function avatarSource(row) {
    var src = row.image || row.icon || "";
    if (src === "")
        return "";
    if (src.charAt(0) === "/")
        return "file://" + src;
    return row.image || /^[a-z]+:/.test(src) ? src : "image://icon/" + src;
}
