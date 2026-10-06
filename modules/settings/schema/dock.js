.pragma library

// Dock: the running-app indicator. The rest of the dock options live in
// "All dock options" (dock-classic). Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "dock",
    "icon": "dock",
    "title": "prefs.cat.dock",
    "description": "prefs.cat.dock.desc",
    "keywords": "dock taskbar apps indicator running dot line glow brush",
    "sections": [
        {
            "id": "indicator",
            "title": "prefs.dock.section.indicator",
            "entries": [
                {
                    "key": "dock.showRunningIndicators",
                    "type": "toggle",
                    "label": "shell.show_running_indicators",
                    "description": "prefs.dock.running.desc",
                    "keywords": "running apps dots indicator"
                },
                {
                    "key": "dock.indicator",
                    "type": "selector",
                    "options": [
                        {
                            "value": "dot",
                            "label": "prefs.dock.indicator.dot"
                        },
                        {
                            "value": "line",
                            "label": "prefs.dock.indicator.line"
                        },
                        {
                            "value": "glow",
                            "label": "prefs.dock.indicator.glow"
                        },
                        {
                            "value": "brush",
                            "label": "prefs.dock.indicator.brush"
                        }
                    ],
                    "label": "prefs.dock.indicator",
                    "description": "prefs.dock.indicator.desc",
                    "keywords": "dock indicator running dot line glow brush style"
                }
            ]
        }
    ]
};
