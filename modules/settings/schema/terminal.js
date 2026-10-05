.pragma library
.import "../../theme/AppThemes.js" as AppThemes

// Terminal & Apps: the terminal the shell launches, kitty font/opacity and
// external app theming (modules/theme/AppThemes.js registry, one toggle per
// app in config apps.theming). Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "terminal",
    "icon": "terminal",
    "title": "prefs.cat.terminal",
    "description": "prefs.cat.terminal.desc",
    "keywords": "terminal kitty command apps launch shell theming gtk qt discord spotify telegram firefox papirus neovim sddm",
    "sections": [
        {
            "id": "terminal",
            "title": "system.terminal.title",
            "entries": [
                {
                    "key": "general.terminal",
                    "type": "text",
                    "monospace": true,
                    "placeholder": "prefs.term.terminal.placeholder",
                    "label": "system.terminal.title",
                    "description": "system.terminal.description",
                    "keywords": "terminal emulator kitty foot alacritty wezterm ghostty"
                },
                {
                    "key": "general.terminalAdvanced",
                    "type": "toggle",
                    "label": "system.terminal.advanced",
                    "description": "system.terminal.advanced_description",
                    "keywords": "terminal advanced custom command template"
                },
                {
                    "key": "general.terminalCommand",
                    "type": "text",
                    "monospace": true,
                    "placeholder": "prefs.term.command.placeholder",
                    "visibleWhen": {
                        "key": "general.terminalAdvanced",
                        "equals": true
                    },
                    "label": "system.terminal.open_with",
                    "description": "prefs.term.command.desc",
                    "keywords": "terminal command template $TERMINAL $COMMAND gnome-terminal konsole"
                }
            ]
        },
        {
            "id": "kitty",
            "title": "prefs.term.section.kitty",
            "entries": [
                {
                    "key": "apps.kitty.font",
                    "type": "font",
                    "sizeKey": "apps.kitty.fontSize",
                    "sizeUnit": "pt",
                    "monospace": true,
                    "placeholder": "prefs.term.kitty_font.placeholder",
                    "keys": ["apps.kitty.font", "apps.kitty.fontSize"],
                    "enabledWhen": {
                        "key": "apps.theming.kitty",
                        "equals": true
                    },
                    "label": "prefs.term.kitty_font",
                    "description": "prefs.term.kitty_font.desc",
                    "keywords": "kitty font family size monospace terminal"
                },
                {
                    "key": "theme.terminalOpacity",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.01,
                    "specialValues": [
                        {
                            "value": -1,
                            "label": "prefs.term.opacity.preset"
                        }
                    ],
                    "enabledWhen": {
                        "key": "apps.theming.kitty",
                        "equals": true
                    },
                    "label": "prefs.term.opacity",
                    "description": "prefs.term.opacity.desc",
                    "keywords": "kitty terminal opacity transparency background alpha"
                },
                {
                    "id": "apps.kitty.glass",
                    "type": "custom",
                    "component": "TerminalGlassLink",
                    "resettable": false,
                    "label": "prefs.term.glass",
                    "description": "prefs.term.glass.desc",
                    "keywords": "glass terminal surface blur opacity kitty"
                }
            ]
        },
        {
            "id": "theming",
            "title": "prefs.term.section.theming",
            "entries": [
                {
                    "id": "apps.theming",
                    "type": "custom",
                    "component": "AppThemingEditor",
                    "keys": AppThemes.ids().map(function (id) {
                        return "apps.theming." + id;
                    }),
                    "label": "prefs.term.theming",
                    "description": "prefs.term.theming.desc",
                    "keywords": "app theming colors palette gtk qt kitty discord vesktop spotify spicetify telegram firefox zen papirus neovim nvim sddm regenerate status installed"
                }
            ]
        }
    ]
};
