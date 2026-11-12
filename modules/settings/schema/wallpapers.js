.pragma library

// Wallpapers: library, folders, transitions. Entry format: see
// modules/settings/AGENTS.md.

// True while the shell animates: not 0 ms, not the "off" profile driving the
// shell (Config.animDuration is 0 then; palette fades and wallpaper
// transitions are skipped).
var ANIMATED = {
    "all": [
        {
            "key": "theme.animDuration",
            "notEquals": 0
        },
        {
            "not": {
                "all": [
                    {
                        "key": "compositor.motionProfile",
                        "equals": "off"
                    },
                    {
                        "key": "compositor.motionShell",
                        "notEquals": false
                    }
                ]
            }
        }
    ]
};

var category = {
    "id": "wallpapers",
    "icon": "image",
    "title": "prefs.cat.wallpapers",
    "description": "prefs.cat.wallpapers.desc",
    "keywords": "wallpaper background picture image folder video",
    "stage": "WallpaperStage",
    "hero": {
        "left": ["wallpaper.browser"],
        "hint": "prefs.wall.hero_hint"
    },
    "row": ["panorama", "transition", "colours"],
    "sections": [
        {
            "id": "library",
            "title": "prefs.wall.section.library",
            "entries": [
                {
                    "id": "wallpaper.browser",
                    "type": "custom",
                    "component": "WallpaperStrip",
                    "resettable": false,
                    "label": "prefs.wall.current",
                    "description": "prefs.wall.current.desc",
                    "keywords": "current wallpaper pick choose thumbnails gallery"
                }
            ]
        },
        {
            "id": "panorama",
            "title": "prefs.wall.section.panorama",
            "entries": [
                {
                    "key": "desktop.wallpaperMode",
                    "type": "selector",
                    "options": [
                        {
                            "value": "fill",
                            "label": "prefs.wall.mode.fill"
                        },
                        {
                            "value": "panorama",
                            "label": "prefs.wall.mode.panorama"
                        }
                    ],
                    "display": "cards",
                    "thumb": "WallFitThumb",
                    "label": "prefs.wall.mode",
                    "description": "prefs.wall.mode.desc",
                    "keywords": "panorama emaki scroll wide pan workspace fill crop parallax"
                },
                {
                    "key": "desktop.panoramaParallax",
                    "advanced": true,
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "desktop.wallpaperMode",
                        "equals": "panorama"
                    },
                    "label": "prefs.wall.parallax",
                    "description": "prefs.wall.parallax.desc",
                    "keywords": "parallax depth layers map near far 3d"
                }
            ]
        },
        {
            "id": "transition",
            "title": "prefs.wall.section.transition",
            "entries": [
                {
                    "key": "desktop.wallpaperTransition",
                    "reason": "prefs.disabled.motion_off",
                    "enabledWhen": ANIMATED,
                    "type": "selector",
                    "options": [
                        {
                            "value": "grow",
                            "label": "shell.desktop.transition.grow"
                        },
                        {
                            "value": "wipe",
                            "label": "shell.desktop.transition.wipe"
                        },
                        {
                            "value": "dissolve",
                            "label": "shell.desktop.transition.dissolve"
                        },
                        {
                            "value": "fade",
                            "label": "shell.desktop.transition.fade"
                        },
                        {
                            "value": "random",
                            "label": "shell.desktop.transition.random"
                        },
                        {
                            "value": "none",
                            "label": "shell.desktop.transition.none"
                        }
                    ],
                    "display": "cards",
                    "thumb": "WallTransitionThumb",
                    "label": "prefs.wall.transition",
                    "description": "prefs.wall.transition.desc",
                    "keywords": "transition animation grow wipe dissolve fade random shader effect"
                },
                {
                    "key": "desktop.wallpaperTransitionDuration",
                    "reason": "prefs.disabled.motion_off",
                    "advanced": true,
                    "enabledWhen": ANIMATED,
                    "type": "slider",
                    "min": 100,
                    "max": 3000,
                    "step": 50,
                    "unit": "ms",
                    "visibleWhen": {
                        "key": "desktop.wallpaperTransition",
                        "notEquals": "none"
                    },
                    "label": "prefs.wall.transition_duration",
                    "description": "prefs.wall.transition_duration.desc",
                    "keywords": "transition duration speed time"
                }
            ]
        },
        {
            "id": "colours",
            "title": "prefs.wall.section.colours",
            "entries": [
                {
                    "id": "wallpaper.colours",
                    "type": "custom",
                    "component": "WallpaperColours",
                    "resettable": false,
                    "label": "prefs.wall.colours",
                    "description": "prefs.wall.colours.desc",
                    "keywords": "colours colors palette from wallpaper matugen scheme accent"
                }
            ]
        },
        {
            "id": "folders",
            "title": "prefs.wall.section.folders",
            "entries": [
                {
                    "key": "desktop.wallpaperFolders",
                    "type": "custom",
                    "component": "FolderList",
                    "label": "prefs.wall.folders",
                    "description": "prefs.wall.folders.desc",
                    "keywords": "folder directory path location library add remove multiple"
                },
                {
                    "id": "wallpaper.screens",
                    "type": "custom",
                    "component": "WallpaperScreens",
                    "resettable": false,
                    "label": "prefs.wall.per_screen",
                    "description": "prefs.wall.per_screen.desc",
                    "keywords": "per screen monitor own wallpaper each display apply all"
                }
            ]
        },
        {
            "id": "more",
            "title": "prefs.wall.section.more",
            "advanced": true,
            "entries": [
                {
                    "id": "wallpaper.rotation",
                    "type": "custom",
                    "component": "ComingSoonRow",
                    "resettable": false,
                    "label": "prefs.wall.rotation",
                    "description": "prefs.wall.rotation.desc",
                    "keywords": "auto rotate slideshow cycle timer change interval"
                }
            ]
        }
    ]
};
