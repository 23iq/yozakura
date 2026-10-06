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
        "icon": "logout",
        "labelKey": "powermenu.exit_session",
        "argv": null,
        "confirm": true
    },
    {
        "id": "reboot",
        "icon": "reboot",
        "labelKey": "powermenu.reboot",
        "argv": ["systemctl", "reboot"],
        "confirm": true
    },
    {
        "id": "shutdown",
        "icon": "shutdown",
        "labelKey": "powermenu.power_off",
        "argv": ["systemctl", "poweroff"],
        "confirm": true
    }
];

// [{id, icon, label, argv, confirm}] with glyphs from `icons` (Icons) and
// labels from `t` (I18n.t).
function build(exitArgv, t, icons) {
    return ACTIONS.map(function (a) {
        return {
            "id": a.id,
            "icon": icons ? (icons[a.icon] || "") : "",
            "label": t ? t(a.labelKey) : a.labelKey,
            "argv": a.argv ? a.argv.slice() : (exitArgv || []).slice(),
            "confirm": !!a.confirm
        };
    });
}
