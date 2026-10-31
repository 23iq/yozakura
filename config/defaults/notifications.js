.pragma library

// Notification popups, rules and Do Not Disturb. Behaviour:
// modules/notifications/NotificationPolicy.js (pure, node-tested) used by
// modules/services/Notifications.qml; presentation "notch" grows toasts from
// the notch, "corner" shows classic toasts (modules/notifications/CornerToasts.qml),
// "auto" follows the bar style of the active preset.
var data = {
    // Notch toast look: card | pill.
    "notchStyle": "card",
    "presentation": "auto",
    "position": "auto",
    "screens": [],
    "timeout": 5000,
    "maxVisible": 3,
    "groupByApp": true,
    // presentation "strips": tanzaku hanging on a thread from a screen edge
    // (modules/notifications/strips/). material plain | paper | washi
    // (a procedural texture tinted from the palette), edge auto | top |
    // bottom | left | right (auto = top, under a top bar).
    "strips": {
        "material": "plain",
        "thread": true,
        "sway": true,
        "maxVisible": 5,
        "edge": "auto"
    },
    "historySize": 100,
    "sound": {
        "enabled": false,
        "file": ""
    },
    "rules": [],
    "dnd": {
        "enabled": false,
        "allowCritical": true,
        "schedule": {
            "enabled": false,
            "from": "22:00",
            "to": "07:00",
            "days": [0, 1, 2, 3, 4, 5, 6]
        }
    }
}
