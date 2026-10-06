.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/terminal.js (format: config/meta/Meta.js).

var description = "Terminal look: the fish prompt (Starship or oh-my-posh) following the shell palette, the greeting, and kitty padding and cursor.";

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
        "enum": Enums.TERMINAL_GREETINGS,
        "description": "What fish prints when a terminal opens."
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
