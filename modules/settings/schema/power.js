.pragma library

// Power: the battery and power profile (the stage), battery saver, what
// happens while you are away (one idle timeline, the lock command) and
// around sleep (two switches). The raw idle listeners (IdleCommands) and
// the sleep commands (the switches set them) are advanced: the tab's More
// card holds them. Entry format: see modules/settings/AGENTS.md.

function command(key, label, description, placeholder, keywords, advanced) {
    return {
        "key": key,
        "advanced": advanced !== false,
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
                command("system.idle.general.lock_cmd", "settings.system.lock_command", "prefs.sys.lock_cmd.desc", "idle.lock_cmd", "lock screen command idle", false)
            ]
        },
        {
            // the raw listeners (a command at a time), for what the timeline
            // does not draw: a group of the tab's More card (IdleCommands)
            "id": "commands",
            "title": "prefs.power.section.commands",
            "advanced": true,
            "entries": [
                {
                    "id": "power.commands",
                    "type": "custom",
                    "component": "IdleCommands",
                    "part": true,
                    "keys": ["system.idle.listeners"],
                    "label": "prefs.power.section.commands",
                    "description": "prefs.sys.idle_listeners.desc",
                    "keywords": "idle listener timeout screen off dim brightness lock suspend sleep hypridle command advanced",
                    "list": {
                        "key": "system.idle.listeners",
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
