.pragma library

// Soft, ink-like motion (Sumi-e): gentle eases without overshoot, windows fade and
// barely grow, workspaces cross-fade. Nothing overshoots. Calm, not slow:
// fades decelerate (gentleInk) and nothing takes longer than 300 ms; only the
// workspace cross-fade eases in and out.
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
            "speed": 3,
            "style": "popin 92%"
        },
        "windowsOut": {
            "curve": "gentleBreath",
            "speed": 2.2,
            "style": "popin 95%"
        },
        "windowsMove": {
            "curve": "gentleInk",
            "speed": 3
        },
        "layers": {
            "curve": "gentleInk",
            "speed": 2.5,
            "style": "fade"
        },
        "fade": {
            "curve": "gentleInk",
            "speed": 2.5
        },
        "border": {
            "curve": "gentleBreath",
            "speed": 5
        },
        "workspaces": {
            "curve": "gentleBreath",
            "speed": 3,
            "style": "fade"
        },
        "specialWorkspace": {
            "curve": "gentleInk",
            "speed": 3,
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
