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
