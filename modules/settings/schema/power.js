.pragma library

// Power: the battery and power profile (the stage), battery saver, what
// happens while you are away (one idle timeline) and around sleep (two
// switches). The raw idle listeners are in the More sheet; the lock and
// sleep commands are out of the window (`yozakura config`). Entry format: see modules/settings/AGENTS.md.

function command(key, label, description, placeholder, keywords) {
    return {
        "key": key,
        "advanced": true,
        "type": "text",
        "monospace": true,
        "placeholder": placeholder,
        "label": label,
        "description": description,
        "keywords": keywords
    };
}

function toggle(key, label, description, keywords) {
    return {
        "key": key,
        "type": "toggle",
        "label": label,
        "description": description,
        "keywords": keywords
    };
}

var category = {
    "id": "power",
    "icon": "batteryHigh",
    "title": "prefs.cat.power",
    "description": "prefs.cat.power.desc",
    "keywords": "power idle sleep suspend lock screen off dim timeout battery hypridle profile performance saver balanced",
    "stage": "PowerStage",
    "row": ["idle", "power"],
    "sections": [
        {
            "id": "idle",
            "title": "prefs.power.section.away",
            "entries": [
                {
                    "id": "power.idle",
                    "type": "custom",
                    "component": "IdleTimeline",
                    "keys": ["system.idle.listeners"],
                    "label": "prefs.power.idle",
                    "description": "prefs.power.idle.desc",
                    "keywords": "idle away timeout dim lock screen off sleep suspend minutes timeline hypridle"
                },
                toggle("performance.batterySaver", "system.performance.battery_saver", "system.performance.battery_saver_desc", "battery saver power laptop unplugged visualizer cava wavy wallpaper border pulse"),
                command("system.idle.general.lock_cmd", "settings.system.lock_command", "prefs.sys.lock_cmd.desc", "idle.lock_cmd", "lock screen command idle")
            ]
        },
        {
            // the raw listeners (a command at a time), for what the timeline
            // does not draw: in the More sheet
            "id": "commands",
            "title": "prefs.power.section.commands",
            "entries": [
                {
                    "key": "system.idle.listeners",
                    "part": true,
                    "type": "list",
                    "fields": [
                        {
                            "key": "timeout",
                            "type": "number",
                            "min": 5,
                            "max": 7200,
                            "step": 5,
                            "unit": "s",
                            "label": "idle.timeout"
                        },
                        {
                            "key": "onTimeout",
                            "type": "text",
                            "monospace": true,
                            "placeholder": "prefs.sys.idle_on_timeout.placeholder",
                            "flex": 0.5,
                            "label": "idle.on_timeout"
                        },
                        {
                            "key": "onResume",
                            "type": "text",
                            "monospace": true,
                            "placeholder": "prefs.sys.idle_on_resume.placeholder",
                            "flex": 0.5,
                            "label": "idle.on_resume"
                        }
                    ],
                    "newItem": {
                        "timeout": 60,
                        "onTimeout": "",
                        "onResume": ""
                    },
                    "itemLabel": "idle.listener_n",
                    "addLabel": "idle.add_listener",
                    "emptyLabel": "prefs.sys.idle_listeners.empty",
                    "label": "idle.listeners",
                    "description": "prefs.sys.idle_listeners.desc",
                    "keywords": "idle listener timeout screen off dim brightness lock suspend sleep hypridle"
                }
            ]
        },
        {
            "id": "power",
            "title": "prefs.power.section.sleep",
            "entries": [
                {
                    "id": "power.sleep",
                    "type": "custom",
                    "component": "SleepSwitches",
                    "keys": ["system.idle.general.before_sleep_cmd", "system.idle.general.after_sleep_cmd"],
                    "label": "prefs.power.sleep",
                    "description": "prefs.power.sleep.desc",
                    "keywords": "sleep suspend lock before resume wake screen on after"
                },
                command("system.idle.general.before_sleep_cmd", "settings.system.before_sleep", "prefs.sys.before_sleep.desc", "idle.before_sleep", "suspend sleep before lock command power"),
                command("system.idle.general.after_sleep_cmd", "settings.system.after_sleep", "prefs.sys.after_sleep.desc", "idle.after_sleep", "resume wake after sleep command power screen on")
            ]
        }
    ]
};
