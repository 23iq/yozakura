.pragma library

// Assistant sidebar extras, spliced into ai.js (its side and width are
// declared there): whether the sidebar starts pinned. Entry format: see
// modules/settings/AGENTS.md.

var sections = [
    {
        "id": "sidebar",
        "title": "prefs.sidebar.section.sidebar",
        "entries": [
            {
                "key": "ai.sidebarPinnedOnStartup",
                "type": "toggle",
                "label": "prefs.sidebar.pinned",
                "description": "prefs.sidebar.pinned.desc",
                "keywords": "assistant sidebar pin pinned startup keep open visible"
            }
        ]
    }
];
