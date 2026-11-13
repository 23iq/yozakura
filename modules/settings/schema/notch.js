.pragma library

// Notch & Activities: the dynamic island and live activities. Entry format:
// see modules/settings/AGENTS.md.

var category = {
    "id": "notch",
    "icon": "dotsThree",
    "title": "prefs.cat.notch",
    "description": "prefs.cat.notch.desc",
    "keywords": "notch island dynamic activities visualizer media panels",
    "stage": "IslandStage",
    "hero": {
        "hint": "prefs.notch.hero_hint"
    },
    "row": [{ "id": "notch", "weight": 1.2 }, { "id": "media", "weight": 1 }, { "id": "activities", "weight": 1.3 }],
    "sections": [
        {
            "id": "notch",
            "title": "prefs.notch.section.notch",
            "entries": [
                {
                    "key": "notch.enabled",
                    "type": "toggle",
                    "label": "prefs.notch.enabled",
                    "description": "prefs.notch.enabled.desc",
                    "keywords": "island notch show hide on off enable disable"
                },
                {
                    "key": "notch.style",
                    "type": "selector",
                    "display": "cards",
                    "thumb": "IslandShapeThumb",
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
                    "label": "prefs.label.island_shape",
                    "description": "prefs.notch.theme.desc",
                    "keywords": "notch style island attached floating pill dot minimal"
                },
                {
                    "key": "notch.align",
                    "type": "selector",
                    "options": [
                        {
                            "value": "start",
                            "label": "prefs.notch.align.start",
                            "icon": "alignLeft"
                        },
                        {
                            "value": "center",
                            "label": "prefs.notch.align.center",
                            "icon": "alignCenter"
                        },
                        {
                            "value": "end",
                            "label": "prefs.notch.align.end",
                            "icon": "alignRight"
                        }
                    ],
                    "label": "prefs.label.island_align",
                    "description": "prefs.notch.align.desc",
                    "keywords": "notch align alignment left right corner start center end"
                },
                {
                    "key": "notch.keepHidden",
                    "type": "toggle",
                    "label": "prefs.notch.hide_until_hovered",
                    "description": "prefs.notch.keep_hidden.desc",
                    "keywords": "hide notch autohide"
                },
                {
                    "key": "notch.hoverRegionHeight",
                    "advanced": true,
                    "type": "slider",
                    "min": 8,
                    "max": 40,
                    "step": 1,
                    "unit": "px",
                    "label": "prefs.notch.hover_region",
                    "description": "prefs.notch.hover_region.desc",
                    "keywords": "hover region trigger area reveal"
                }
            ]
        },
        {
            "id": "behaviour",
            "title": "prefs.notch.section.opening",
            "entries": [
                {
                    "key": "notch.expandOn",
                    "type": "selector",
                    "options": [
                        {
                            "value": "hover",
                            "label": "shell.notch.expand_on_hover",
                            "icon": "cursor"
                        },
                        {
                            "value": "click",
                            "label": "shell.notch.expand_on_click",
                            "icon": "hand"
                        }
                    ],
                    "label": "shell.notch.expand_on",
                    "description": "prefs.notch.expand_on.desc",
                    "keywords": "notch panel expand open hover click activities media downloads"
                }
            ]
        },
        {
            "id": "place",
            "title": "prefs.notch.section.place",
            "entries": [
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
                    "label": "prefs.label.island_edge",
                    "description": "prefs.notch.position.desc",
                    "keywords": "notch position top bottom left right side vertical edge"
                }
            ]
        },
        {
            "id": "media",
            "title": "prefs.notch.section.media",
            "entries": [
                {
                    // notch.disableHoverExpansion shown positively: on = the
                    // island grows into the media panel (the key stays).
                    "key": "notch.disableHoverExpansion",
                    "type": "toggle",
                    "invert": true,
                    "label": "prefs.notch.media_panel",
                    "description": "prefs.notch.media_panel.desc",
                    "keywords": "media panel card player hover expand grow preview disable"
                },
                {
                    "key": "notch.mediaStyle",
                    "enabledWhen": {
                        "key": "notch.disableHoverExpansion",
                        "equals": false
                    },
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
                    "label": "prefs.notch.media_panel_style",
                    "description": "prefs.notch.media_style.desc",
                    "keywords": "media player panel style row artwork album cover spotify"
                },
                {
                    "key": "notch.visualizer",
                    "enabledWhen": {
                        "key": "notch.disableHoverExpansion",
                        "equals": false
                    },
                    "type": "toggle",
                    "label": "prefs.notch.media_visualizer",
                    "description": "prefs.notch.visualizer.desc",
                    "keywords": "audio visualizer cava bars music"
                }
            ]
        },
        {
            // what the island shows while nothing plays (rare)
            "id": "idle",
            "title": "prefs.notch.section.idle",
            "entries": [
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
                    "label": "prefs.notch.activities_where",
                    "description": "prefs.notch.activities_in.desc",
                    "keywords": "live activities chips bar notch downloads timer recording grow place"
                },
                {
                    "key": "notch.activities",
                    "type": "custom",
                    "component": "IslandActivitiesEditor",
                    "label": "prefs.notch.island_activities",
                    "description": "prefs.notch.island_activities.desc",
                    "keywords": "island activities order reorder drag side left right enable media osd volume brightness battery charging bluetooth extras install timers privacy"
                },
                {
                    "key": "notch.liveActivities",
                    "type": "custom",
                    "component": "ActivitiesEditor",
                    "label": "prefs.notch.activity_kinds",
                    "description": "prefs.notch.activities.desc",
                    "keywords": "live activities recording microphone camera privacy screen share pomodoro timer progress downloads steam torrent qbittorrent transmission deluge aria2 syncthing curl wget yt-dlp copy rsync pacman flatpak heroic lutris presentation"
                },
                {
                    "id": "notch.notifLink",
                    "type": "custom",
                    "component": "PageLink",
                    "target": "notifications",
                    "targetSection": "presentation",
                    "linkText": "prefs.notch.notif_link.open",
                    "resettable": false,
                    "label": "prefs.notch.notif_link",
                    "description": "prefs.notch.notif_link.desc",
                    "keywords": "notification notch compact card island"
                },
                {
                    "id": "notch.timerLink",
                    "type": "custom",
                    "component": "PageLink",
                    "target": "timers",
                    "targetSection": "notch",
                    "linkText": "prefs.notch.timer_link.open",
                    "resettable": false,
                    "label": "prefs.notch.timer_link",
                    "description": "prefs.notch.timer_link.desc",
                    "keywords": "timer ring text countdown island"
                }
            ]
        }
    ]
};

// The notch and media rows only matter while the island is on (its switch
// heads the Island card); activities also work in the bar.
category.sections.forEach(function (section) {
    if (section.id !== "notch" && section.id !== "media")
        return;
    section.entries.forEach(function (entry) {
        if (entry.key === "notch.enabled")
            return;
        var on = {
            "key": "notch.enabled",
            "equals": true
        };
        entry.visibleWhen = entry.visibleWhen ? {
            "all": [on, entry.visibleWhen]
        } : on;
    });
});
