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
    "keywords": "terminal prompt starship oh-my-posh fish cursor padding kitty command apps launch shell theming gtk qt discord spotify telegram firefox papirus neovim sddm",
    "sections": [
        {
            "id": "look",
            "title": "prefs.term.section.look",
            "entries": [
                {
                    "id": "terminal.look",
                    "type": "custom",
                    "component": "TerminalLookEditor",
                    "keys": ["terminal.prompt", "terminal.enabled"],
                    "label": "prefs.term.look.prompt",
                    "description": "prefs.term.look.prompt.desc",
                    "keywords": "prompt starship oh-my-posh fish powerline nerd font preview theme shell look"
                },
                {
                    "key": "terminal.enabled",
                    "type": "toggle",
                    "label": "prefs.term.look.enabled",
                    "description": "prefs.term.look.enabled.desc",
                    "keywords": "prompt fish enable hook conf.d"
                },
                {
                    "key": "terminal.engine",
                    "type": "selector",
                    "options": [
                        {
                            "value": "starship",
                            "label": "prefs.term.look.engine.starship",
                            "icon": "lightning"
                        },
                        {
                            "value": "ohmyposh",
                            "label": "prefs.term.look.engine.ohmyposh",
                            "icon": "magicWand"
                        }
                    ],
                    "label": "prefs.term.look.engine",
                    "description": "prefs.term.look.engine.desc",
                    "keywords": "prompt engine starship oh-my-posh omp"
                },
                {
                    "key": "terminal.greeting",
                    "type": "selector",
                    "options": [
                        {
                            "value": "none",
                            "label": "prefs.term.look.greeting.none"
                        },
                        {
                            "value": "fastfetch",
                            "label": "prefs.term.look.greeting.fastfetch"
                        }
                    ],
                    "label": "prefs.term.look.greeting",
                    "description": "prefs.term.look.greeting.desc",
                    "keywords": "greeting fastfetch welcome fish_greeting"
                },
                {
                    "key": "terminal.padding",
                    "type": "slider",
                    "min": 0,
                    "max": 64,
                    "step": 1,
                    "unit": "px",
                    "label": "prefs.term.look.padding",
                    "description": "prefs.term.look.padding.desc",
                    "keywords": "kitty padding margin window spacing"
                },
                {
                    "key": "terminal.cursorShape",
                    "type": "custom",
                    "component": "CursorShapeChips",
                    "label": "prefs.term.look.cursor",
                    "description": "prefs.term.look.cursor.desc",
                    "keywords": "kitty cursor shape block beam underline caret"
                },
                {
                    "key": "terminal.cursorBlink",
                    "type": "toggle",
                    "label": "prefs.term.look.blink",
                    "description": "prefs.term.look.blink.desc",
                    "keywords": "kitty cursor blink blinking"
                }
            ]
        },
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
