.pragma library

// Overview: the workspace overview (mission control) layout and preview
// size. The wallpaper blur behind it lives in Desktop, live window
// thumbnails in System > Performance. Entry format: see
// modules/settings/AGENTS.md.

var category = {
    "id": "overview",
    "icon": "overview",
    "title": "prefs.cat.overview",
    "description": "prefs.cat.overview.desc",
    "keywords": "overview expose mission control workspaces grid strip filmstrip",
    "sections": [
        {
            "id": "layout",
            "title": "prefs.overview.section.layout",
            "entries": [
                {
                    "key": "overview.style",
                    "type": "selector",
                    "options": [
                        {
                            "value": "grid",
                            "label": "settings.shell.overview_style_grid",
                            "icon": "squaresFour"
                        },
                        {
                            "value": "strip",
                            "label": "settings.shell.overview_style_strip",
                            "icon": "columns"
                        }
                    ],
                    "label": "prefs.overview.style",
                    "description": "prefs.overview.style.desc",
                    "keywords": "overview style layout grid strip filmstrip carousel"
                },
                {
                    "key": "overview.rows",
                    "type": "slider",
                    "min": 1,
                    "max": 10,
                    "step": 1,
                    "label": "prefs.overview.rows",
                    "description": "prefs.overview.rows.desc",
                    "keywords": "overview rows grid vertical workspaces count"
                },
                {
                    "key": "overview.columns",
                    "type": "slider",
                    "min": 1,
                    "max": 10,
                    "step": 1,
                    "label": "prefs.overview.columns",
                    "description": "prefs.overview.columns.desc",
                    "keywords": "overview columns grid horizontal workspaces count visible"
                }
            ]
        },
        {
            "id": "size",
            "title": "prefs.overview.section.size",
            "entries": [
                {
                    "key": "overview.scale",
                    "type": "slider",
                    "min": 0.05,
                    "max": 0.5,
                    "step": 0.01,
                    "label": "prefs.overview.scale",
                    "description": "prefs.overview.scale.desc",
                    "keywords": "overview scale zoom size preview thumbnails"
                },
                {
                    "key": "overview.workspaceSpacing",
                    "type": "slider",
                    "min": 0,
                    "max": 64,
                    "step": 1,
                    "unit": "px",
                    "advanced": true,
                    "label": "prefs.overview.spacing",
                    "description": "prefs.overview.spacing.desc",
                    "keywords": "overview spacing gap between workspaces"
                }
            ]
        },
        {
            "id": "wallpaper",
            "title": "prefs.overview.section.wallpaper",
            "entries": [
                {
                    "key": "desktop.blurWallpaperOnOverview",
                    "type": "toggle",
                    "label": "prefs.desktop.overview_blur",
                    "description": "prefs.desktop.overview_blur.desc",
                    "keywords": "overview blur wallpaper niri workspaces"
                }
            ]
        }
    ]
};
