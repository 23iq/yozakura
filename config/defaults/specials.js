.pragma library

// Special workspaces (Hyprland scratchpads / niri named workspaces). The two
// defaults, social and dev, are bound by hand (see docs). Global like binds.json: a
// private domain (catalog.LocalDomains) that presets never save, show or
// apply. Item shape and allowed values: config/meta/specials.js; logic:
// modules/specials/Specials.js.
var data = {
    "enabled": true,
    "launchTimeout": 20000,
    "preloadDelay": 4000,
    "workspaces": [
        {
            "id": "social",
            "name": "social",
            "icon": "chatDots",
            "accent": "primary",
            "toggle": { "modifiers": [], "key": "" },
            "send": { "modifiers": [], "key": "" },
            "preload": false,
            "apps": [
                { "id": "ayugram", "name": "AyuGram", "icon": "telegram", "match": "com\\.ayugram\\.desktop|AyuGram", "command": "ayugram-desktop", "ifRunning": "nothing", "rule": false },
                { "id": "vesktop", "name": "Vesktop", "icon": "vesktop", "match": "vesktop", "command": "vesktop", "ifRunning": "nothing", "rule": false }
            ]
        },
        {
            "id": "dev",
            "name": "dev",
            "icon": "code",
            "accent": "secondary",
            "toggle": { "modifiers": [], "key": "" },
            "send": { "modifiers": [], "key": "" },
            "preload": false,
            "apps": [
                { "id": "terminal", "name": "Terminal", "icon": "terminal", "match": "special\\.dev", "command": "ghostty --class=special.dev --gtk-single-instance=false", "ifRunning": "nothing", "rule": false }
            ]
        }
    ]
}
