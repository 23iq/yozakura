.pragma library

// Slow, ink-like motion (Sumi-e): long symmetric eases, windows fade and
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
            "points": [0.45, 0.0, 0.15, 1.0]
        },
        "gentleBreath": {
            "type": "bezier",
            "points": [0.37, 0.0, 0.63, 1.0]
        }
    },
    "leaves": {
        "windows": {
            "curve": "gentleInk",
            "speed": 6,
            "style": "popin 92%"
        },
        "windowsOut": {
            "curve": "gentleBreath",
            "speed": 5,
            "style": "popin 95%"
        },
        "windowsMove": {
            "curve": "gentleInk",
            "speed": 6
        },
        "layers": {
            "curve": "gentleInk",
            "speed": 5,
            "style": "fade"
        },
        "fade": {
            "curve": "gentleBreath",
            "speed": 6
        },
        "border": {
            "curve": "gentleBreath",
            "speed": 8
        },
        "workspaces": {
            "curve": "gentleBreath",
            "speed": 7,
            "style": "fade"
        },
        "specialWorkspace": {
            "curve": "gentleInk",
            "speed": 6,
            "style": "fade"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 1.6,
        "easing": "InOutSine"
    }
};
