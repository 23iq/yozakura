.pragma library

// Power: what happens when the computer is idle, and around sleep (moved out
// of System). Not curated for the window yet: see modules/settings/AGENTS.md,
// CONVERTING A PAGE. Entry format: see modules/settings/AGENTS.md.

function command(key, label, description, placeholder, keywords) {
    return {
        "key": key,
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
    "keywords": "power idle sleep suspend lock screen off dim timeout battery hypridle",
    "sections": [
        {
            "id": "battery",
            "title": "prefs.power.section.battery",
            "entries": [
                toggle("performance.batterySaver", "system.performance.battery_saver", "system.performance.battery_saver_desc", "battery saver power laptop unplugged visualizer cava wavy wallpaper border pulse")
            ]
        },
        {
            "id": "idle",
            "title": "settings.system.idle",
            "entries": [
                command("system.idle.general.lock_cmd", "settings.system.lock_command", "prefs.sys.lock_cmd.desc", "idle.lock_cmd", "lock screen command idle"),
                {
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
            ]
        },
        {
            "id": "power",
            "title": "prefs.sys.section.power",
            "entries": [
                command("system.idle.general.before_sleep_cmd", "settings.system.before_sleep", "prefs.sys.before_sleep.desc", "idle.before_sleep", "suspend sleep before lock command power"),
                command("system.idle.general.after_sleep_cmd", "settings.system.after_sleep", "prefs.sys.after_sleep.desc", "idle.after_sleep", "resume wake after sleep command power screen on")
            ]
        }
    ]
};
