.pragma library

// Notification popups, rules and Do Not Disturb. Behaviour:
// modules/notifications/NotificationPolicy.js (pure, node-tested) used by
// modules/services/Notifications.qml; presentation "notch" grows toasts from
// the notch, "corner" shows classic toasts (modules/notifications/CornerToasts.qml),
// "auto" follows the bar style of the active preset.
var data = {
    "presentation": "auto",
    "position": "auto",
    "screens": [],
    "timeout": 5000,
    "maxVisible": 3,
    "groupByApp": true,
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
