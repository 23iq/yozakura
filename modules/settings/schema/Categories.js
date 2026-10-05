.pragma library
.import "appearance.js" as Appearance
.import "wallpapers.js" as Wallpapers
.import "bar.js" as Bar
.import "notch.js" as Notch
.import "ai.js" as Ai
.import "input.js" as Input
.import "lockscreen.js" as Lockscreen
.import "launcher.js" as Launcher
.import "desktop.js" as Desktop
.import "windows.js" as Windows
.import "system.js" as System
.import "voice.js" as Voice
.import "updates.js" as Updates
.import "terminal.js" as Terminal
.import "notifications.js" as Notifications
.import "specials.js" as Specials

// Settings information architecture: sidebar groups and categories.
//
// A category is one of:
//   * schema-driven: has `sections` (see appearance.js) - rendered by
//     SettingsPage.qml, searchable entry by entry;
//   * legacy: has `legacy: {source, section}` - an old dashboard panel
//     (path relative to modules/widgets/) hosted unchanged by
//     LegacyPanelHost.qml until it is migrated; `topics` keep it searchable;
//   * a page: has `page` - a hand-written page in modules/settings/.
// Categories not listed in a group are reachable only by search or links
// (e.g. "bar-classic", opened from the Bar page).
// To migrate a legacy category, give it `sections` and drop `legacy`/`topics`.

var groups = [
    {
        "id": "personalize",
        "title": "prefs.group.personalize",
        "categories": ["appearance", "wallpapers", "surfaces"]
    },
    {
        "id": "shell",
        "title": "prefs.group.shell",
        "categories": ["bar", "notch", "launcher", "dock", "overview", "specials", "desktop", "lockscreen", "notifications"]
    },
    {
        "id": "system",
        "title": "prefs.group.system",
        "categories": ["windows", "terminal", "input", "voice", "system", "updates"]
    },
    {
        "id": "connect",
        "title": "prefs.group.connect",
        "categories": ["network", "bluetooth", "sound", "effects"]
    },
    {
        "id": "extend",
        "title": "prefs.group.extend",
        "categories": ["ai", "sidebar", "mods", "presets", "about"]
    }
];

function legacy(id, icon, title, description, source, section, keywords, topics) {
    return {
        "id": id,
        "icon": icon,
        "title": title,
        "description": description,
        "keywords": keywords,
        "legacy": {
            "source": source,
            "section": section || ""
        },
        "topics": topics || []
    };
}

function topic(label, section, keywords) {
    return {
        "label": label,
        "section": section || "",
        "keywords": keywords || ""
    };
}

var categories = [
    Appearance.category,
    Wallpapers.category,
    Bar.category,
    legacy("surfaces", "stack", "prefs.cat.surfaces", "prefs.cat.surfaces.desc", "dashboard/controls/ThemePanel.qml", "", "shadows surfaces variants gradients opacity borders colors theme editor terminal opacity", [
        topic("settings.theme.shadow_opacity", "shadow", "darkness alpha transparency"),
        topic("settings.theme.shadow_blur", "shadow", "softness diffusion"),
        topic("settings.theme.color_variant", "colors", "background popup internal bar pane"),
        topic("theme.gradient_mode", "colors", "linear radial halftone"),
        topic("settings.theme.terminal_opacity", "general", "kitty transparency")
    ]),
    legacy("bar-classic", "squaresFour", "prefs.cat.bar-classic", "prefs.cat.bar-classic.desc", "dashboard/controls/ShellPanel.qml", "bar", "bar launcher icon pill style firefox player screens monitors shadow border", [
        topic("settings.shell.launcher_icon", "bar", "logo symbol path"),
        topic("settings.shell.pill_style", "bar", "squished roundness radius bar"),
        topic("settings.shell.firefox_player", "bar", "browser media music"),
        topic("settings.shell.bar_screens", "bar", "monitor display")
    ]),
    Notch.category,
    Launcher.category,
    legacy("dock", "dock", "prefs.cat.dock", "prefs.cat.dock.desc", "dashboard/controls/ShellPanel.qml", "dock", "dock taskbar apps favorites pinned", [
        topic("settings.shell.dock_position", "dock", "left bottom right edge"),
        topic("settings.shell.dock_icon_size", "dock", "width height pixels apps")
    ]),
    legacy("overview", "overview", "prefs.cat.overview", "prefs.cat.overview.desc", "dashboard/controls/ShellPanel.qml", "overview", "overview expose mission control workspaces grid", [
        topic("settings.shell.overview_rows", "overview", "grid layout vertical"),
        topic("settings.shell.overview_scale", "overview", "zoom size preview")
    ]),
    Desktop.category,
    Lockscreen.category,
    Notifications.category,
    Specials.category,
    Windows.category,
    Terminal.category,
    Input.category,
    System.category,
    Voice.category,
    Updates.category,
    legacy("network", "wifiHigh", "prefs.cat.network", "prefs.cat.network.desc", "dashboard/controls/WifiPanel.qml", "", "network wifi internet ethernet connection", []),
    legacy("bluetooth", "bluetooth", "prefs.cat.bluetooth", "prefs.cat.bluetooth.desc", "dashboard/controls/BluetoothPanel.qml", "", "bluetooth devices pairing headphones", []),
    legacy("sound", "speakerHigh", "prefs.cat.sound", "prefs.cat.sound.desc", "dashboard/controls/AudioMixerPanel.qml", "", "sound audio volume mixer output input microphone speaker", []),
    legacy("effects", "waveform", "prefs.cat.effects", "prefs.cat.effects.desc", "dashboard/controls/EasyEffectsPanel.qml", "", "equalizer easyeffects bass audio effects", []),
    Ai.category,
    legacy("ai-providers", "robot", "ai.providers", "prefs.ai.providers.desc", "config/AiPanel.qml", "", "ai api key provider openai anthropic gemini mistral groq ollama minimax custom endpoint", []),
    legacy("sidebar", "sidebar", "prefs.cat.sidebar", "prefs.cat.sidebar.desc", "dashboard/controls/ShellPanel.qml", "sidebar", "assistant sidebar ai panel width position", []),
    legacy("mods", "puzzlePiece", "prefs.cat.mods", "prefs.cat.mods.desc", "dashboard/controls/ModsPanel.qml", "", "mods extensions plugins modifications install", []),
    {
        "id": "presets",
        "icon": "magicWand",
        "title": "prefs.cat.presets",
        "description": "prefs.cat.presets.desc",
        "keywords": "presets studio save load profiles themes layouts looks gallery mixer mix duplicate import export share try",
        "page": "PresetStudio"
    },
    {
        "id": "about",
        "icon": "info",
        "title": "prefs.cat.about",
        "description": "prefs.cat.about.desc",
        "keywords": "about version credits license notice yozakura",
        "page": "AboutPage"
    }
];

function byId(id) {
    for (var i = 0; i < categories.length; i++) {
        if (categories[i].id === id)
            return categories[i];
    }
    return null;
}

// Sidebar model: [{group, title, categories: [category...]}] in order.
function sidebar() {
    return groups.map(function (g) {
        return {
            "id": g.id,
            "title": g.title,
            "categories": g.categories.map(byId).filter(function (c) {
                return c !== null;
            })
        };
    });
}

// Categories in sidebar order (keyboard navigation).
function ordered() {
    var out = [];
    groups.forEach(function (g) {
        g.categories.forEach(function (id) {
            var c = byId(id);
            if (c)
                out.push(c);
        });
    });
    return out;
}
