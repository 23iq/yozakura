.pragma library

// Notch & Activities: the dynamic island and live activities. Entry format:
// see modules/settings/AGENTS.md.

var category = {
    "id": "notch",
    "icon": "dotsThree",
    "title": "prefs.cat.notch",
    "description": "prefs.cat.notch.desc",
    "keywords": "notch island dynamic activities visualizer media panels",
    "sections": [
        {
            "id": "notch",
            "title": "prefs.notch.section.notch",
            "entries": [
                {
                    "key": "notch.style",
                    "type": "selector",
                    "options": [
                        {
                            "value": "attached",
                            "label": "prefs.notch.style.attached"
                        },
                        {
                            "value": "island",
                            "label": "shell.dock.island"
                        },
                        {
                            "value": "pill",
                            "label": "prefs.notch.style.pill"
                        }
                    ],
                    "label": "prefs.notch.theme",
                    "description": "prefs.notch.theme.desc",
                    "keywords": "notch style island attached floating pill dot minimal"
                },
                {
                    "key": "notch.position",
                    "type": "selector",
                    "options": [
                        {
                            "value": "top",
                            "label": "common.top",
                            "icon": "arrowUp"
                        },
                        {
                            "value": "bottom",
                            "label": "common.bottom",
                            "icon": "arrowDown"
                        },
                        {
                            "value": "left",
                            "label": "common.left",
                            "icon": "arrowLeft"
                        },
                        {
                            "value": "right",
                            "label": "common.right",
                            "icon": "arrowRight"
                        }
                    ],
                    "label": "prefs.notch.position",
                    "description": "prefs.notch.position.desc",
                    "keywords": "notch position top bottom left right side vertical edge"
                },
                {
                    "key": "notch.align",
                    "type": "selector",
                    "options": [
                        {
                            "value": "start",
                            "label": "prefs.notch.align.start"
                        },
                        {
                            "value": "center",
                            "label": "prefs.notch.align.center"
                        },
                        {
                            "value": "end",
                            "label": "prefs.notch.align.end"
                        }
                    ],
                    "label": "prefs.notch.align",
                    "description": "prefs.notch.align.desc",
                    "keywords": "notch align alignment left right corner start center end"
                },
                {
                    "key": "notch.expandOn",
                    "type": "selector",
                    "options": [
                        {
                            "value": "hover",
                            "label": "shell.notch.expand_on_hover"
                        },
                        {
                            "value": "click",
                            "label": "shell.notch.expand_on_click"
                        }
                    ],
                    "label": "shell.notch.expand_on",
                    "description": "prefs.notch.expand_on.desc",
                    "keywords": "notch panel expand open hover click activities media downloads"
                },
                {
                    "key": "notch.disableHoverExpansion",
                    "advanced": true,
                    "type": "toggle",
                    "label": "shell.notch.disable_hover_expansion",
                    "description": "prefs.notch.hover_expansion.desc",
                    "keywords": "hover expand grow media preview"
                },
                {
                    "key": "notch.keepHidden",
                    "type": "toggle",
                    "label": "shell.notch.keep_hidden",
                    "description": "prefs.notch.keep_hidden.desc",
                    "keywords": "hide notch autohide"
                },
                {
                    "key": "notch.hoverRegionHeight",
                    "advanced": true,
                    "type": "slider",
                    "min": 0,
                    "max": 40,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "notch.keepHidden",
                        "equals": true
                    },
                    "label": "prefs.notch.hover_region",
                    "description": "prefs.notch.hover_region.desc",
                    "keywords": "hover region trigger area reveal"
                }
            ]
        },
        {
            "id": "media",
            "title": "prefs.notch.section.media",
            "entries": [
                {
                    "key": "notch.mediaStyle",
                    "type": "selector",
                    "options": [
                        {
                            "value": "row",
                            "label": "prefs.notch.media_style.row"
                        },
                        {
                            "value": "artwork",
                            "label": "prefs.notch.media_style.artwork"
                        }
                    ],
                    "label": "prefs.notch.media_style",
                    "description": "prefs.notch.media_style.desc",
                    "keywords": "media player panel style row artwork album cover spotify"
                },
                {
                    "key": "notch.visualizer",
                    "type": "toggle",
                    "label": "shell.notch.visualizer",
                    "description": "prefs.notch.visualizer.desc",
                    "keywords": "audio visualizer cava bars music"
                },
                {
                    "key": "notch.noMediaDisplay",
                    "type": "selector",
                    "options": [
                        {
                            "value": "userHost",
                            "label": "shell.notch.user_host"
                        },
                        {
                            "value": "compositor",
                            "label": "shell.notch.compositor"
                        },
                        {
                            "value": "custom",
                            "label": "theme.custom"
                        }
                    ],
                    "label": "shell.no_media_display",
                    "description": "prefs.notch.idle.desc",
                    "keywords": "idle text user host compositor custom nothing playing"
                },
                {
                    "key": "notch.customText",
                    "type": "text",
                    "visibleWhen": {
                        "key": "notch.noMediaDisplay",
                        "equals": "custom"
                    },
                    "label": "shell.notch.custom_text",
                    "description": "prefs.notch.custom_text.desc",
                    "keywords": "custom text label idle"
                }
            ]
        },
        {
            "id": "activities",
            "title": "prefs.notch.section.activities",
            "entries": [
                {
                    "key": "notch.activities",
                    "type": "custom",
                    "component": "IslandActivitiesEditor",
                    "label": "prefs.notch.island_activities",
                    "description": "prefs.notch.island_activities.desc",
                    "keywords": "island activities order reorder drag side left right enable media osd volume brightness battery charging bluetooth extras install timers privacy"
                },
                {
                    "key": "notifications.notchStyle",
                    "type": "selector",
                    "options": [
                        {
                            "value": "card",
                            "label": "prefs.notifications.notch_style.card"
                        },
                        {
                            "value": "compact",
                            "label": "prefs.notifications.notch_style.compact"
                        }
                    ],
                    "label": "prefs.notifications.notch_style",
                    "description": "prefs.notifications.notch_style.desc",
                    "keywords": "notification notch compact card one line"
                },
                {
                    "key": "notch.activitiesIn",
                    "type": "selector",
                    "options": [
                        {
                            "value": "auto",
                            "label": "prefs.notch.activities_in.auto"
                        },
                        {
                            "value": "notch",
                            "label": "prefs.notch.activities_in.notch"
                        },
                        {
                            "value": "bar",
                            "label": "prefs.notch.activities_in.bar"
                        }
                    ],
                    "label": "prefs.notch.activities_in",
                    "description": "prefs.notch.activities_in.desc",
                    "keywords": "live activities chips bar notch downloads timer recording grow place"
                },
                {
                    "key": "notch.liveActivities",
                    "type": "custom",
                    "component": "ActivitiesEditor",
                    "label": "shell.activities",
                    "description": "prefs.notch.activities.desc",
                    "keywords": "live activities recording microphone camera privacy screen share pomodoro timer progress downloads steam torrent qbittorrent transmission deluge aria2 syncthing curl wget yt-dlp copy rsync pacman flatpak heroic lutris presentation"
                }
            ]
        },
        {
            "id": "timers",
            "title": "prefs.notch.section.timers",
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
                }
            ]
        }
    ]
};
