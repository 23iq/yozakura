.pragma library

// Wallpapers: library, folders, transitions. Entry format: see
// modules/settings/AGENTS.md.

var category = {
    "id": "wallpapers",
    "icon": "image",
    "title": "prefs.cat.wallpapers",
    "description": "prefs.cat.wallpapers.desc",
    "keywords": "wallpaper background picture image folder video",
    "sections": [
        {
            "id": "library",
            "title": "prefs.wall.section.library",
            "entries": [
                {
                    "id": "wallpaper.browser",
                    "type": "custom",
                    "component": "WallpaperGrid",
                    "resettable": false,
                    "label": "prefs.wall.current",
                    "description": "prefs.wall.current.desc",
                    "keywords": "current wallpaper pick choose thumbnails gallery"
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
                }
            ]
        },
        {
            "id": "transition",
            "title": "prefs.wall.section.transition",
            "entries": [
                {
                    "key": "desktop.wallpaperTransition",
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
                    "preview": "TransitionPreview",
                    "label": "prefs.wall.transition",
                    "description": "prefs.wall.transition.desc",
                    "keywords": "transition animation grow wipe dissolve fade random shader effect"
                },
                {
                    "key": "desktop.wallpaperTransitionDuration",
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
            "id": "more",
            "title": "prefs.wall.section.more",
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
