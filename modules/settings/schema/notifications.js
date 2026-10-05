.pragma library
.import "../../notifications/NotificationPolicy.js" as Policy

// Notifications: presentation (notch-born or corner toasts), timing,
// grouping, sound, per-app rules and Do Not Disturb. Behaviour:
// modules/notifications/NotificationPolicy.js. Entry format: see
// modules/settings/AGENTS.md.

var POSITION_ICONS = {
    "auto": "magicWand",
    "top-left": "arrowUp",
    "top": "arrowUp",
    "top-right": "arrowUp",
    "bottom-left": "arrowDown",
    "bottom": "arrowDown",
    "bottom-right": "arrowDown"
};

var RULE_LABELS = {
    "mute": "prefs.notif.rule.mute",
    "priority": "prefs.notif.rule.priority",
    "alwaysShow": "prefs.notif.rule.alwaysShow",
    "soundOff": "prefs.notif.rule.soundOff"
};

var RULE_ICONS = {
    "mute": "bellSlash",
    "priority": "bellRinging",
    "alwaysShow": "eye",
    "soundOff": "speakerSlash"
};

// Days a DND window starts on, Monday first (0 = Sunday, as Date.getDay()).
var DAYS = [1, 2, 3, 4, 5, 6, 0];
var DAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

var NOT_NOTCH = {
    "key": "notifications.presentation",
    "notEquals": "notch"
};

var SCHEDULE_ON = {
    "key": "notifications.dnd.schedule.enabled",
    "equals": true
};

var TIME_PATTERN = "^([01]?\\d|2[0-3]):[0-5]\\d$";

var category = {
    "id": "notifications",
    "icon": "bell",
    "title": "prefs.cat.notifications",
    "description": "prefs.cat.notifications.desc",
    "keywords": "notifications popups toasts do not disturb dnd alerts rules mute history sound",
    "sections": [
        {
            "id": "presentation",
            "title": "prefs.notif.section.presentation",
            "entries": [
                {
                    "id": "notifications.status",
                    "type": "custom",
                    "component": "NotificationsStatus",
                    "resettable": false,
                    "label": "prefs.notif.status",
                    "description": "prefs.notif.status.desc",
                    "keywords": "test notification preview send now dnd active"
                },
                {
                    "key": "notifications.presentation",
                    "type": "selector",
                    "options": [
                        {
                            "value": "auto",
                            "label": "prefs.notif.presentation.auto",
                            "icon": "magicWand"
                        },
                        {
                            "value": "notch",
                            "label": "prefs.notif.presentation.notch",
                            "icon": "dotsThree"
                        },
                        {
                            "value": "corner",
                            "label": "prefs.notif.presentation.corner",
                            "icon": "frameCorners"
                        }
                    ],
                    "label": "prefs.notif.presentation",
                    "description": "prefs.notif.presentation.desc",
                    "keywords": "notch toast corner popup island style presentation where"
                },
                {
                    "key": "notifications.position",
                    "type": "selector",
                    "options": Policy.POSITIONS.map(function (p) {
                        return {
                            "value": p,
                            "label": "prefs.notif.position." + p,
                            "icon": POSITION_ICONS[p]
                        };
                    }),
                    "visibleWhen": NOT_NOTCH,
                    "label": "prefs.notif.position",
                    "description": "prefs.notif.position.desc",
                    "keywords": "corner position top bottom left right center"
                },
                {
                    "key": "notifications.screens",
                    "type": "screens",
                    "label": "prefs.notif.screens",
                    "description": "prefs.notif.screens.desc",
                    "keywords": "monitor screen display multi-monitor where"
                }
            ]
        },
        {
            "id": "behaviour",
            "title": "prefs.notif.section.behaviour",
            "entries": [
                {
                    "key": "notifications.timeout",
                    "type": "slider",
                    "min": 0,
                    "max": 30000,
                    "step": 500,
                    "unit": "ms",
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.notif.timeout.never"
                        }
                    ],
                    "label": "prefs.notif.timeout",
                    "description": "prefs.notif.timeout.desc",
                    "keywords": "timeout duration seconds hide dismiss expire"
                },
                {
                    "key": "notifications.maxVisible",
                    "type": "number",
                    "min": 1,
                    "max": 10,
                    "label": "prefs.notif.max_visible",
                    "description": "prefs.notif.max_visible.desc",
                    "keywords": "maximum visible stack count limit"
                },
                {
                    "key": "notifications.groupByApp",
                    "type": "toggle",
                    "label": "prefs.notif.group",
                    "description": "prefs.notif.group.desc",
                    "keywords": "group grouping stack app same application"
                },
                {
                    "key": "notifications.historySize",
                    "type": "number",
                    "min": 0,
                    "max": 500,
                    "step": 10,
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.notif.history.none"
                        }
                    ],
                    "label": "prefs.notif.history",
                    "description": "prefs.notif.history.desc",
                    "keywords": "history size keep remember stored count dashboard"
                }
            ]
        },
        {
            "id": "sound",
            "title": "prefs.notif.section.sound",
            "entries": [
                {
                    "key": "notifications.sound.enabled",
                    "type": "toggle",
                    "label": "prefs.notif.sound",
                    "description": "prefs.notif.sound.desc",
                    "keywords": "sound chime beep audio play"
                },
                {
                    "key": "notifications.sound.file",
                    "type": "path",
                    "pathKind": "file",
                    "filter": "Audio | *.wav *.ogg *.oga *.mp3 *.flac *.opus",
                    "placeholder": "prefs.notif.sound_file.placeholder",
                    "visibleWhen": {
                        "key": "notifications.sound.enabled",
                        "equals": true
                    },
                    "label": "prefs.notif.sound_file",
                    "description": "prefs.notif.sound_file.desc",
                    "keywords": "sound file custom wav ogg chime"
                }
            ]
        },
        {
            "id": "rules",
            "title": "prefs.notif.section.rules",
            "entries": [
                {
                    "key": "notifications.rules",
                    "type": "list",
                    "fields": [
                        {
                            "key": "app",
                            "type": "text",
                            "placeholder": "prefs.notif.rule.app.placeholder",
                            "flex": 0.4,
                            "label": "prefs.notif.rule.app"
                        },
                        {
                            "key": "action",
                            "type": "selector",
                            "options": Policy.RULE_ACTIONS.map(function (a) {
                                return {
                                    "value": a,
                                    "label": RULE_LABELS[a],
                                    "icon": RULE_ICONS[a]
                                };
                            }),
                            "label": "prefs.notif.rule.action"
                        }
                    ],
                    "newItem": {
                        "app": "",
                        "action": "mute"
                    },
                    "itemLabel": "prefs.notif.rule.n",
                    "addLabel": "prefs.notif.rule.add",
                    "emptyLabel": "prefs.notif.rules.empty",
                    "label": "prefs.notif.rules",
                    "description": "prefs.notif.rules.desc",
                    "keywords": "rules per app mute priority always show sound off silence block discord spotify"
                }
            ]
        },
        {
            "id": "dnd",
            "title": "prefs.notif.section.dnd",
            "entries": [
                {
                    "key": "notifications.dnd.enabled",
                    "type": "toggle",
                    "label": "prefs.notif.dnd",
                    "description": "prefs.notif.dnd.desc",
                    "keywords": "do not disturb dnd silence quiet focus mute all"
                },
                {
                    "key": "notifications.dnd.allowCritical",
                    "type": "toggle",
                    "label": "prefs.notif.dnd_critical",
                    "description": "prefs.notif.dnd_critical.desc",
                    "keywords": "critical urgent battery alarm bypass dnd"
                },
                {
                    "key": "notifications.dnd.schedule.enabled",
                    "type": "toggle",
                    "label": "prefs.notif.schedule",
                    "description": "prefs.notif.schedule.desc",
                    "keywords": "schedule night quiet hours automatic dnd time"
                },
                {
                    "key": "notifications.dnd.schedule.from",
                    "type": "text",
                    "monospace": true,
                    "pattern": TIME_PATTERN,
                    "placeholder": "prefs.notif.time.placeholder",
                    "visibleWhen": SCHEDULE_ON,
                    "label": "prefs.notif.schedule_from",
                    "description": "prefs.notif.schedule_from.desc",
                    "keywords": "start begin from time hour"
                },
                {
                    "key": "notifications.dnd.schedule.to",
                    "type": "text",
                    "monospace": true,
                    "pattern": TIME_PATTERN,
                    "placeholder": "prefs.notif.time.placeholder",
                    "visibleWhen": SCHEDULE_ON,
                    "label": "prefs.notif.schedule_to",
                    "description": "prefs.notif.schedule_to.desc",
                    "keywords": "end until to time hour"
                },
                {
                    "key": "notifications.dnd.schedule.days",
                    "type": "multiselect",
                    "options": DAYS.map(function (d) {
                        return {
                            "value": d,
                            "label": "weather.day." + DAY_KEYS[d]
                        };
                    }),
                    "visibleWhen": SCHEDULE_ON,
                    "label": "prefs.notif.schedule_days",
                    "description": "prefs.notif.schedule_days.desc",
                    "keywords": "days week weekdays weekend monday sunday"
                }
            ]
        }
    ]
};
