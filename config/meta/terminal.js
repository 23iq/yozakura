.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/terminal.js (format: config/meta/Meta.js).

var description = "Terminal look: the fish prompt (Starship or oh-my-posh) following the shell palette, the fastfetch greeting of new terminals (fish, bash, zsh), and kitty padding and cursor.";

var keys = {
    "enabled": {
        "local": true,
        "description": "Write the prompt config and the fish hook (fish conf.d). Off removes the hook; config.fish is never touched. Machine-local: presets never switch the prompt on or off."
    },
    "engine": {
        "local": true,
        "enum": Enums.TERMINAL_ENGINES,
        "description": "Prompt engine. Machine-local: presets never switch engines."
    },
    "prompt": {
        "description": "Prompt preset id (assets/terminal/prompts/<id>.json; list them with `yozakura term list`)."
    },
    "greeting": {
        "local": true,
        "enum": Enums.TERMINAL_GREETINGS,
        "description": "What a new terminal prints: fastfetch runs once per terminal in fish, bash and zsh (interactive shells on a terminal only; not in tmux/screen panes or nested shells), whether or not the prompt is on. bash/zsh get one marked line in ~/.bashrc / ~/.zshrc that sources <config>/<app>/greeting.sh; turning it off removes it. The rc lines are only written once the user switched the greeting on in this version (`yozakura term greeting on`, Settings, the setup wizard); set otherwise, or on from before the update, it runs in fish only. Machine-local: presets never switch the greeting on or off (they can carry its look)."
    },
    "fastfetchPreset": {
        "enum": Enums.TERMINAL_FETCH_PRESETS,
        "description": "Greeting look (assets/terminal/fastfetch/<id>.jsonc, colored from the shell palette; `yozakura term greeting presets`). own = plain fastfetch with your own ~/.config/fastfetch config (never edited)."
    },
    "fastfetchLogo": {
        "enum": Enums.TERMINAL_FETCH_LOGOS,
        "description": "Greeting logo: the distribution's (fastfetch detection), the sakura text logo, a file of yours (fastfetchLogoPath) or none. Ignored by the own and minimal looks."
    },
    "fastfetchLogoPath": {
        "local": true,
        "format": "path",
        "description": "Custom greeting logo (fastfetchLogo custom): an absolute path to a UTF-8 text file (up to 64 KiB; $1..$5 colour markers, or ANSI colours: other escape sequences are removed) or a PNG (up to 8 MiB, shown in kitty; other terminals get the sakura text logo). Machine-local."
    },
    "padding": {
        "min": 0,
        "max": 64,
        "unit": "px",
        "description": "Kitty window padding."
    },
    "cursorShape": {
        "enum": Enums.TERMINAL_CURSOR_SHAPES,
        "description": "Kitty cursor shape."
    },
    "cursorBlink": {
        "description": "Blink the kitty cursor."
    }
};
