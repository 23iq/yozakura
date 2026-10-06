.pragma library

// Timers & focus: notch timers (svc/timers through TimersService), alarm
// sound, Pomodoro lengths, focus mode, quick input and quick note.
// Entry format: see modules/settings/AGENTS.md.

function toggle(key, label, description, keywords, extra) {
    var e = {
        "key": key,
        "type": "toggle",
        "label": label,
        "description": description,
        "keywords": keywords
    };
    for (var k in (extra || {}))
        e[k] = extra[k];
    return e;
}

function number(key, label, description, min, max, step, unit, keywords, extra) {
    var e = {
        "key": key,
        "type": "number",
        "min": min,
        "max": max,
        "step": step,
        "unit": unit,
        "label": label,
        "description": description,
        "keywords": keywords
    };
    for (var k in (extra || {}))
        e[k] = extra[k];
    return e;
}

var SOUND_ON = {
    "key": "system.timers.sound",
    "equals": true
};

var category = {
    "id": "timers",
    "icon": "timer",
    "title": "prefs.cat.timers",
    "description": "prefs.cat.timers.desc",
    "keywords": "timers timer alarm reminder stopwatch pomodoro focus mode do not disturb quick note clock notch countdown",
    "sections": [
        {
            "id": "notch",
            "title": "prefs.timers.section.notch",
            "entries": [
                {
                    "key": "system.timers.notchStyle",
                    "type": "selector",
                    "options": [
                        {
                            "value": "ring",
                            "label": "prefs.timers.style.ring",
                            "icon": "circleNotch"
                        },
                        {
                            "value": "text",
                            "label": "prefs.timers.style.text",
                            "icon": "textT"
                        }
                    ],
                    "label": "prefs.timers.style",
                    "description": "prefs.timers.style.desc",
                    "keywords": "notch ring progress text countdown display"
                },
                toggle("system.timers.showSeconds", "prefs.timers.seconds", "prefs.timers.seconds.desc", "seconds countdown format mm:ss"),
                toggle("system.timers.showStopwatch", "prefs.timers.stopwatch", "prefs.timers.stopwatch.desc", "stopwatch notch elapsed"),
                number("system.timers.reminderLead", "prefs.timers.reminder_lead", "prefs.timers.reminder_lead.desc", 0, 1440, 5, "min", "reminder alarm upcoming notch soon", {
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.timers.reminder_lead.never"
                        }
                    ]
                }),
                {
                    "key": "system.timers.clockClick",
                    "type": "selector",
                    "options": [
                        {
                            "value": "popup",
                            "label": "prefs.timers.clock.popup",
                            "icon": "calendar"
                        },
                        {
                            "value": "timers",
                            "label": "prefs.timers.clock.timers",
                            "icon": "timer"
                        }
                    ],
                    "label": "prefs.timers.clock",
                    "description": "prefs.timers.clock.desc",
                    "keywords": "bar clock click calendar weather timers open"
                }
            ]
        },
        {
            "id": "alarm",
            "title": "prefs.timers.section.alarm",
            "entries": [
                toggle("system.timers.pulseOnFinish", "prefs.timers.pulse", "prefs.timers.pulse.desc", "pulse blink alarm finished notch"),
                toggle("system.timers.alarmPanel", "prefs.timers.alarm_panel", "prefs.timers.alarm_panel.desc", "alarm panel notch stop snooze finished"),
                toggle("system.timers.sound", "prefs.timers.sound", "prefs.timers.sound.desc", "sound alarm tone ring audio"),
                {
                    "key": "system.timers.soundFile",
                    "type": "path",
                    "pathKind": "file",
                    "filter": "Audio | *.wav *.ogg *.oga *.mp3 *.flac *.opus",
                    "placeholder": "prefs.timers.sound_file.placeholder",
                    "visibleWhen": SOUND_ON,
                    "label": "prefs.timers.sound_file",
                    "description": "prefs.timers.sound_file.desc",
                    "keywords": "alarm sound file tone custom"
                },
                number("system.timers.alarmRepeat", "prefs.timers.repeat", "prefs.timers.repeat.desc", 0, 60, 1, "", "alarm repeat ring times loop", {
                    "visibleWhen": SOUND_ON,
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.timers.repeat.forever"
                        }
                    ]
                }),
                number("system.timers.alarmInterval", "prefs.timers.interval", "prefs.timers.interval.desc", 1, 60, 1, "s", "alarm repeat interval pause", {
                    "visibleWhen": SOUND_ON
                }),
                toggle("system.timers.phaseSound", "prefs.timers.phase_sound", "prefs.timers.phase_sound.desc", "pomodoro phase break chime sound", {
                    "visibleWhen": SOUND_ON
                })
            ]
        },
        {
            "id": "pomodoro",
            "title": "prefs.timers.section.pomodoro",
            "entries": [
                number("system.pomodoro.workTime", "prefs.timers.pomo_work", "prefs.timers.pomo_work.desc", 60, 14400, 60, "s", "pomodoro work focus length"),
                number("system.pomodoro.restTime", "prefs.timers.pomo_rest", "prefs.timers.pomo_rest.desc", 60, 7200, 60, "s", "pomodoro break rest length"),
                toggle("system.pomodoro.autoStart", "prefs.timers.pomo_auto", "prefs.timers.pomo_auto.desc", "pomodoro auto start next phase continue"),
                toggle("system.pomodoro.syncSpotify", "prefs.timers.pomo_spotify", "prefs.timers.pomo_spotify.desc", "pomodoro spotify music pause play")
            ]
        },
        {
            "id": "focus",
            "title": "prefs.timers.section.focus",
            "entries": [
                number("system.focus.minutes", "prefs.timers.focus_minutes", "prefs.timers.focus_minutes.desc", 5, 480, 5, "min", "focus mode length minutes default"),
                toggle("system.focus.dnd", "prefs.timers.focus_dnd", "prefs.timers.focus_dnd.desc", "focus do not disturb dnd notifications silence"),
                toggle("system.focus.hideBadges", "prefs.timers.focus_badges", "prefs.timers.focus_badges.desc", "focus badges unread bell notifications hide"),
                toggle("system.focus.summary", "prefs.timers.focus_summary", "prefs.timers.focus_summary.desc", "focus summary missed notifications end")
            ]
        },
        {
            "id": "input",
            "title": "prefs.timers.section.input",
            "entries": [
                {
                    "key": "prefix.timers",
                    "type": "text",
                    "monospace": true,
                    "pattern": "^\\S{1,8}$",
                    "label": "prefs.timers.prefix",
                    "description": "prefs.timers.prefix.desc",
                    "keywords": "launcher prefix timers t"
                },
                {
                    "key": "system.timers.noteTitle",
                    "type": "text",
                    "placeholder": "quicknote.inbox",
                    "label": "prefs.timers.note_title",
                    "description": "prefs.timers.note_title.desc",
                    "keywords": "quick note inbox notes title capture"
                }
            ]
        }
    ]
};
