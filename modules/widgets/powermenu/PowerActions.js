.pragma library

// The power menu's actions, shared by every style (styles/*.qml through
// PowerMenuModel.qml). argv runs detached, never through a shell; logout
// asks the daemon (exitArgv). Destructive actions need a HoldToConfirm hold.

var ACTIONS = [
    {
        "id": "lock",
        "icon": "lock",
        "labelKey": "powermenu.lock_session",
        "argv": ["loginctl", "lock-session"]
    },
    {
        "id": "suspend",
        "icon": "suspend",
        "labelKey": "powermenu.suspend",
        "argv": ["systemctl", "suspend"]
    },
    {
        "id": "hibernate",
        "icon": "hibernate",
        "labelKey": "powermenu.hibernate",
        "argv": ["systemctl", "hibernate"]
    },
    {
        "id": "logout",
        "holdKey": "powermenu.hold.logout",
        "icon": "logout",
        "labelKey": "powermenu.exit_session",
        "argv": null,
        "confirm": true
    },
    {
        "id": "reboot",
        "holdKey": "powermenu.hold.reboot",
        "icon": "reboot",
        "labelKey": "powermenu.reboot",
        "argv": ["systemctl", "reboot"],
        "confirm": true
    },
    {
        "id": "shutdown",
        "holdKey": "powermenu.hold.shutdown",
        "icon": "shutdown",
        "labelKey": "powermenu.power_off",
        "argv": ["systemctl", "poweroff"],
        "confirm": true
    }
];

// [{id, icon, label, hold, argv, confirm}] with glyphs from `icons` (Icons)
// and labels from `t` (I18n.t); `hold` is the "Hold to shut down" hint of a
// confirm action ("" otherwise).
function build(exitArgv, t, icons) {
    return ACTIONS.map(function (a) {
        return {
            "id": a.id,
            "icon": icons ? (icons[a.icon] || "") : "",
            "label": t ? t(a.labelKey) : a.labelKey,
            "hold": a.holdKey ? (t ? t(a.holdKey) : a.holdKey) : "",
            "argv": a.argv ? a.argv.slice() : (exitArgv || []).slice(),
            "confirm": !!a.confirm
        };
    });
}

// Uptime in seconds as "3d 4h", "2h 05m" or "12m" (the menu's caption).
function formatUptime(seconds) {
    var s = Math.floor(Number(seconds));
    if (!(s >= 0))
        return "";
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    if (d > 0)
        return d + "d " + h + "h";
    if (h > 0)
        return h + "h " + (m < 10 ? "0" : "") + m + "m";
    return m + "m";
}

// The quiet caption over the menu from `cat /proc/uptime
// /proc/sys/kernel/hostname` output and $USER: "up 2h 05m · lazy@arch".
// Parts that cannot be read are left out ("" when nothing is known).
// `upLabel` is the translated "up %1".
function caption(procText, user, upLabel) {
    var lines = String(procText || "").split("\n");
    var up = /^\s*(\d+(?:\.\d+)?)\s/.exec(lines[0] || "");
    var host = (lines[1] || "").trim();
    var parts = [];
    if (up)
        parts.push(String(upLabel || "up %1").replace("%1", formatUptime(parseFloat(up[1]))));
    if (user && host)
        parts.push(user + "@" + host);
    return parts.join(" · ");
}

// Sizes of the fullscreen menu for a screen `height` px tall: the kit
// IconButton size, the label role and the caption / hint role. Large
// screens (>= 1200 px, e.g. 2560x1440) get the hero size so the actions
// read from a distance; smaller ones the regular large size.
function heroScale(height) {
    if (height >= 1200)
        return {
            "size": "xl",
            "label": "title",
            "caption": "body"
        };
    if (height >= 900)
        return {
            "size": "l",
            "label": "body",
            "caption": "secondary"
        };
    return {
        "size": "l",
        "label": "secondary",
        "caption": "caption"
    };
}
