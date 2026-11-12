.pragma library

// System: language, weather, performance, idle
// listeners, power/sleep commands, monitored disks, clipboard storage and
// the file converter.
// Entry format: see modules/settings/AGENTS.md.

function toggle(key, label, description, keywords) {
    return {
        "key": key,
        "type": "toggle",
        "label": label,
        "description": description,
        "keywords": keywords
    };
}

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

var category = {
    "id": "system",
    "icon": "circuitry",
    "title": "prefs.cat.system",
    "description": "prefs.cat.system.desc",
    "keywords": "system idle power sleep suspend lock performance language weather prefixes disks clipboard polkit password",
    "sections": [
        {
            "id": "language",
            "title": "settings.system.language",
            "entries": [
                {
                    "key": "system.language",
                    "type": "custom",
                    "component": "LanguagePicker",
                    "label": "prefs.label.interface_language",
                    "description": "prefs.sys.language.desc",
                    "keywords": "language locale translation i18n english spanish russian auto"
                }
            ]
        },
        {
            "id": "exclusive",
            "compositor": "hyprland",
            "entries": [
                {
                    "id": "system.exclusive",
                    "type": "custom",
                    "component": "ExclusiveCard",
                    "compositor": "hyprland",
                    "resettable": false,
                    "label": "prefs.exclusive.title",
                    "description": "prefs.exclusive.desc",
                    "keywords": "exclusive only shell hyprland waybar mako dunst backup restore minimal config user.lua disable other bars daemons systemd"
                }
            ]
        },
        {
            "id": "weather",
            "title": "settings.system.weather",
            "entries": [
                {
                    "key": "weather.location",
                    "type": "text",
                    "placeholder": "weather.location_placeholder",
                    "label": "weather.location",
                    "description": "prefs.sys.weather_location.desc",
                    "keywords": "weather city country place location gps coordinates"
                },
                {
                    "key": "weather.unit",
                    "type": "selector",
                    "options": [
                        {
                            "value": "C",
                            "label": "weather.celsius"
                        },
                        {
                            "value": "F",
                            "label": "weather.fahrenheit"
                        }
                    ],
                    "label": "settings.system.temperature_unit",
                    "description": "prefs.sys.weather_unit.desc",
                    "keywords": "temperature unit celsius fahrenheit"
                }
            ]
        },
        {
            "id": "performance",
            "title": "settings.system.performance",
            "entries": [
                toggle("performance.blurTransition", "performance.blur_transition", "system.performance.blur_transition_desc", "blur transition animation panels"),
                toggle("performance.windowPreview", "performance.window_preview", "system.performance.window_preview_desc", "window preview thumbnails overview dock"),
                toggle("performance.wavyLine", "performance.wavy_line", "system.performance.wavy_line_desc", "wavy line progress media animation"),
                toggle("performance.pauseWallpaperOnFullscreen", "system.performance.pause_wallpaper_fullscreen", "system.performance.pause_wallpaper_fullscreen_desc", "video wallpaper fullscreen game pause"),
                toggle("performance.pauseWallpaperWhenCovered", "system.performance.pause_wallpaper_covered", "system.performance.pause_wallpaper_covered_desc", "video wallpaper covered tiled windows gaps monocle pause"),
                toggle("performance.pauseWallpaperOnIdle", "system.performance.pause_wallpaper_idle", "system.performance.pause_wallpaper_idle_desc", "video wallpaper idle away afk inactive pause"),
                {
                    "key": "performance.pauseWallpaperIdleDelay",
                    "type": "number",
                    "label": "system.performance.pause_wallpaper_idle_delay",
                    "description": "system.performance.pause_wallpaper_idle_delay_desc",
                    "keywords": "video wallpaper idle delay seconds timeout pause",
                    "min": 5,
                    "max": 3600,
                    "step": 5,
                    "unit": "s",
                    "visibleWhen": {
                        "key": "performance.pauseWallpaperOnIdle",
                        "equals": true
                    }
                },
                toggle("performance.pauseWallpaperOnBattery", "system.performance.pause_wallpaper_battery", "system.performance.pause_wallpaper_battery_desc", "video wallpaper battery power laptop unplugged pause"),
                toggle("performance.videoWallpaperDownscale", "system.performance.video_downscale", "system.performance.video_downscale_desc", "video wallpaper downscale resolution transcode ffmpeg cpu fps 4k"),
                toggle("performance.batterySaver", "system.performance.battery_saver", "system.performance.battery_saver_desc", "battery saver power laptop unplugged visualizer cava wavy wallpaper border pulse"),
                {
                    "key": "performance.visualizerFps",
                    "type": "number",
                    "advanced": true,
                    "min": 15,
                    "max": 60,
                    "step": 5,
                    "unit": "fps",
                    "label": "system.performance.visualizer_fps",
                    "description": "system.performance.visualizer_fps_desc",
                    "keywords": "visualizer cava audio bars frame rate fps cpu"
                },
                {
                    "key": "performance.warmViews",
                    "type": "toggle",
                    "advanced": true,
                    "label": "system.performance.warm_views",
                    "description": "system.performance.warm_views_desc",
                    "keywords": "warm preload prepare startup launcher memory"
                },
                {
                    "key": "performance.hidePanelInFullscreen",
                    "type": "toggle",
                    "advanced": true,
                    "label": "system.performance.hide_panel_fullscreen",
                    "description": "system.performance.hide_panel_fullscreen_desc",
                    "keywords": "fullscreen game video panel bar unmap scanout overlay surface"
                },
                {
                    "key": "performance.compactOsd",
                    "type": "toggle",
                    "advanced": true,
                    "label": "system.performance.compact_osd",
                    "description": "system.performance.compact_osd_desc",
                    "keywords": "osd volume brightness window surface size memory"
                },
                {
                    "key": "performance.splitFrame",
                    "type": "toggle",
                    "advanced": true,
                    "label": "system.performance.split_frame",
                    "description": "system.performance.split_frame_desc",
                    "keywords": "frame border window surface redraw layer"
                },
                {
                    "key": "performance.settingsKeepAliveMinutes",
                    "type": "number",
                    "advanced": true,
                    "min": 0,
                    "max": 120,
                    "unit": "min",
                    "label": "prefs.sys.settings_keep_alive",
                    "description": "prefs.sys.settings_keep_alive.desc",
                    "keywords": "settings window keep loaded memory reopen instant release",
                    "enabledWhen": {
                        "key": "performance.separateWindows",
                        "equals": false
                    }
                },
                {
                    "key": "performance.separateWindows",
                    "type": "toggle",
                    "advanced": true,
                    "label": "system.performance.separate_windows",
                    "description": "system.performance.separate_windows_desc",
                    "keywords": "separate process settings window setup wizard onboarding memory ram release open slower"
                }
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
        },
        {
            "id": "auth",
            "title": "prefs.sys.section.auth",
            "entries": [
                {
                    "key": "system.polkitAgent",
                    "type": "toggle",
                    "advanced": true,
                    "label": "prefs.sys.polkit_agent",
                    "description": "prefs.sys.polkit_agent.desc",
                    "keywords": "polkit password prompt authentication agent pkexec sudo admin root hyprpolkitagent dialog"
                }
            ]
        },
        {
            "id": "storage",
            "title": "prefs.sys.section.storage",
            "entries": [
                {
                    "key": "system.disks",
                    "type": "list",
                    "itemType": "path",
                    "pathKind": "dir",
                    "newItem": "/",
                    "placeholder": "system.disk_path_placeholder",
                    "addLabel": "system.add_disk",
                    "emptyLabel": "prefs.sys.disks.empty",
                    "label": "system.resources.disks_title",
                    "description": "prefs.sys.disks.desc",
                    "keywords": "disks mount points storage metrics usage home root"
                },
                toggle("system.clipboard.tmpfs", "prefs.sys.clipboard_tmpfs", "prefs.sys.clipboard_tmpfs.desc", "clipboard history tmp tmpfs ram memory reboot privacy")
            ]
        },
        {
            "id": "converter",
            "title": "prefs.sys.section.converter",
            "entries": [
                {
                    "key": "system.converter.outputDir",
                    "type": "path",
                    "pathKind": "dir",
                    "placeholder": "prefs.sys.converter_dir.placeholder",
                    "label": "prefs.sys.converter_dir",
                    "description": "prefs.sys.converter_dir.desc",
                    "keywords": "converter convert output folder directory save results files"
                },
                {
                    "key": "system.converter.quality",
                    "type": "selector",
                    "options": [
                        {
                            "value": "small",
                            "label": "converter.quality.small"
                        },
                        {
                            "value": "balanced",
                            "label": "converter.quality.balanced"
                        },
                        {
                            "value": "best",
                            "label": "converter.quality.best"
                        }
                    ],
                    "label": "prefs.sys.converter_quality",
                    "description": "prefs.sys.converter_quality.desc",
                    "keywords": "converter convert quality size compression mp3 jpg video bitrate"
                },
                toggle("system.converter.openFolder", "prefs.sys.converter_open", "prefs.sys.converter_open.desc", "converter convert open folder show files done finished")
            ]
        }
    ]
};
