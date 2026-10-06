.pragma library

// Soft, ink-like motion (Sumi-e): gentle eases without overshoot, windows fade and
// barely grow, workspaces cross-fade. Nothing overshoots.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "gentle",
    "label": "prefs.motion.profile.gentle",
    "description": "prefs.motion.profile.gentle.desc",
    "icon": "paintBrush",
    "curves": {
        "gentleInk": {
            "type": "bezier",
            "points": [0.25, 0.46, 0.3, 1.0]
        },
        "gentleBreath": {
            "type": "bezier",
            "points": [0.37, 0.0, 0.63, 1.0]
        }
    },
    "leaves": {
        "windows": {
            "curve": "gentleInk",
            "speed": 3.5,
            "style": "popin 92%"
        },
        "windowsOut": {
            "curve": "gentleBreath",
            "speed": 3,
            "style": "popin 95%"
        },
        "windowsMove": {
            "curve": "gentleInk",
            "speed": 3.5
        },
        "layers": {
            "curve": "gentleInk",
            "speed": 3,
            "style": "fade"
        },
        "fade": {
            "curve": "gentleBreath",
            "speed": 3.5
        },
        "border": {
            "curve": "gentleBreath",
            "speed": 5
        },
        "workspaces": {
            "curve": "gentleBreath",
            "speed": 4,
            "style": "fade"
        },
        "specialWorkspace": {
            "curve": "gentleInk",
            "speed": 3.5,
            "style": "fade"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 1.0,
        "easing": "OutSine"
    }
};
