.pragma library

// Launcher: result providers (order, on/off, prefixes) and their options.
// Providers are registered in modules/widgets/launcher/Providers.js. Entry
// format: see modules/settings/AGENTS.md.

var category = {
    "id": "launcher",
    "icon": "magnifyingGlass",
    "title": "prefs.cat.launcher",
    "description": "prefs.cat.launcher.desc",
    "keywords": "launcher search apps run calculator converter currency units files commands ai prefixes",
    "sections": [
        {
            "id": "providers",
            "title": "prefs.launcher.section.providers",
            "entries": [
                {
                    "id": "launcher.providers",
                    "type": "custom",
                    "component": "LauncherProvidersEditor",
                    "keys": ["prefix.launcher.order", "prefix.launcher.disabled", "prefix.calculator", "prefix.commands", "prefix.files", "prefix.ai", "prefix.wallpapers", "prefix.clipboard", "prefix.emoji", "prefix.tmux", "prefix.notes"],
                    "label": "prefs.launcher.providers",
                    "description": "prefs.launcher.providers.desc",
                    "keywords": "providers order enable disable prefix calculator commands files wallpapers ai clipboard emoji tmux notes"
                }
            ]
        },
        {
            "id": "behavior",
            "title": "prefs.launcher.section.behavior",
            "entries": [
                {
                    "key": "prefix.launcher.aiOnTab",
                    "type": "toggle",
                    "label": "prefs.launcher.ai_on_tab",
                    "description": "prefs.launcher.ai_on_tab.desc",
                    "keywords": "tab ai ask assistant quick"
                },
                {
                    "key": "prefix.launcher.filesInMixed",
                    "type": "toggle",
                    "label": "prefs.launcher.files_in_mixed",
                    "description": "prefs.launcher.files_in_mixed.desc",
                    "keywords": "files search results mixed home"
                },
                {
                    "key": "prefix.launcher.fileBackend",
                    "type": "selector",
                    "options": [
                        {
                            "value": "auto",
                            "label": "common.auto"
                        },
                        {
                            "value": "fd",
                            "label": "prefs.launcher.backend.fd"
                        },
                        {
                            "value": "plocate",
                            "label": "prefs.launcher.backend.plocate"
                        }
                    ],
                    "label": "prefs.launcher.file_backend",
                    "description": "prefs.launcher.file_backend.desc",
                    "keywords": "fd plocate locate find search tool"
                },
                {
                    "key": "prefix.launcher.fileMaxResults",
                    "type": "slider",
                    "min": 5,
                    "max": 100,
                    "step": 5,
                    "label": "prefs.launcher.file_max",
                    "description": "prefs.launcher.file_max.desc",
                    "keywords": "files results limit count"
                },
                {
                    "key": "prefix.launcher.currencyRefreshHours",
                    "type": "slider",
                    "min": 1,
                    "max": 72,
                    "step": 1,
                    "unit": "h",
                    "label": "prefs.launcher.currency_refresh",
                    "description": "prefs.launcher.currency_refresh.desc",
                    "keywords": "currency rates exchange refresh offline cache"
                }
            ]
        }
    ]
};
