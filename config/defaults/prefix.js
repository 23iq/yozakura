.pragma library

var data = {
    "clipboard": "cc",
    "emoji": "ee",
    "tmux": "tt",
    "wallpapers": "ww",
    "notes": "nn",
    "calculator": "=",
    "commands": ">",
    "files": "ff",
    "ai": "?",
    "timers": "t",
    "routines": "@",
    "launcher": {
        "order": ["routines", "calculator", "commands", "timers", "apps", "specials", "wallpapers", "files", "ai"],
        "disabled": [],
        "aiOnTab": true,
        "filesInMixed": true,
        "fileBackend": "auto",
        "fileMaxResults": 30,
        "fileExcludes": [".git", "node_modules", ".cache", ".local/share/Trash", "target", "__pycache__", ".venv"],
        "currencyRefreshHours": 12
    }
}
