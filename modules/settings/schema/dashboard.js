.pragma library

// Dashboard: its tabs (order, visibility) and how many stay loaded.
// Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "dashboard",
    "icon": "dotsNine",
    "title": "prefs.cat.dashboard",
    "description": "prefs.cat.dashboard.desc",
    "keywords": "dashboard tabs widgets hub panel memory",
    "sections": [
        {
            "id": "home",
            "title": "prefs.dashboard.section.home",
            "entries": [
                {
                    "key": "layout.dashboard.home",
                    "type": "selector",
                    "options": [
                        {
                            "value": "stage",
                            "label": "prefs.dashboard.home.stage",
                            "icon": "player"
                        },
                        {
                            "value": "composed",
                            "label": "prefs.dashboard.home.composed",
                            "icon": "squaresFour"
                        },
                        {
                            "value": "bento",
                            "label": "prefs.dashboard.home.bento",
                            "icon": "dotsNine"
                        }
                    ],
                    "label": "prefs.dashboard.home",
                    "description": "prefs.dashboard.home.desc",
                    "keywords": "dashboard home view stage composed bento grid widgets layout overview"
                },
                {
                    "key": "layout.dashboard.heroTint",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "layout.dashboard.home",
                        "equals": "stage"
                    },
                    "label": "prefs.dashboard.hero_tint",
                    "description": "prefs.dashboard.hero_tint.desc",
                    "keywords": "dashboard player hero tint album art colour color"
                },
                {
                    "key": "layout.dashboard.showMetrics",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "layout.dashboard.home",
                        "equals": "stage"
                    },
                    "label": "prefs.dashboard.show_metrics",
                    "description": "prefs.dashboard.show_metrics.desc",
                    "keywords": "dashboard metrics cpu ram gpu network strip footer"
                }
            ]
        },
        {
            "id": "tabs",
            "title": "prefs.dashboard.section.tabs",
            "entries": [
                {
                    "key": "layout.dashboard.tabs",
                    "type": "custom",
                    "component": "DashboardTabsEditor",
                    "label": "prefs.dashboard.tabs",
                    "description": "prefs.dashboard.tabs.desc",
                    "keywords": "dashboard tabs order hide show reorder widgets wallpapers metrics rail"
                }
            ]
        },
        {
            "id": "memory",
            "title": "prefs.dashboard.section.memory",
            "entries": [
                {
                    "key": "performance.dashboardPersistTabs",
                    "type": "toggle",
                    "label": "performance.dashboard_persist",
                    "description": "prefs.sys.dashboard_persist.desc",
                    "keywords": "dashboard tabs keep loaded memory"
                },
                {
                    "key": "performance.dashboardMaxPersistentTabs",
                    "type": "number",
                    "advanced": true,
                    "min": 1,
                    "max": 10,
                    "visibleWhen": {
                        "key": "performance.dashboardPersistTabs",
                        "equals": true
                    },
                    "label": "prefs.sys.dashboard_max_tabs",
                    "description": "prefs.sys.dashboard_max_tabs.desc",
                    "keywords": "dashboard tabs memory limit"
                }
            ]
        }
    ]
};
