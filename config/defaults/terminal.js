.pragma library

// Terminal look: the fish prompt (Starship or oh-my-posh, colored from the
// shell palette), the fastfetch greeting (fish, bash, zsh; look, logo) and
// the kitty padding/cursor. Font stays in
// apps.kitty and opacity in theme.terminalOpacity. `enabled` stays false until
// the user picks a prompt: an existing prompt is never replaced silently.
var data = {
    "enabled": false,
    "engine": "starship",
    "prompt": "sakura-powerline",
    "greeting": "none",
    "fastfetchPreset": "own",
    "fastfetchLogo": "sakura",
    "fastfetchLogoPath": "",
    "padding": 12,
    "cursorShape": "beam",
    "cursorBlink": true
}
