.pragma library

// CRT-like: every animation holds, then snaps in one hard step (a cubic
// with both control points pushed to the corners), like a tube warming up.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "stepped",
    "label": "prefs.motion.profile.stepped",
    "description": "prefs.motion.profile.stepped.desc",
    "icon": "monitor",
    "curves": {
        // x(t) has zero slope at t = 0.5: hold - jump - hold.
        "steppedSnap": {
            "type": "bezier",
            "points": [1.0, 0.0, 0.0, 1.0]
        },
        "steppedLinear": {
            "type": "bezier",
            "points": [0.0, 0.0, 1.0, 1.0]
        }
    },
    "leaves": {
        "windows": {
            "curve": "steppedSnap",
            "speed": 1.8,
            "style": "popin 50%"
        },
        "windowsMove": {
            "curve": "steppedSnap",
            "speed": 1.5
        },
        "layers": {
            "curve": "steppedSnap",
            "speed": 1.4,
            "style": "popin 60%"
        },
        "fade": {
            "curve": "steppedSnap",
            "speed": 1.6
        },
        "border": {
            "curve": "steppedLinear",
            "speed": 1
        },
        "workspaces": {
            "curve": "steppedSnap",
            "speed": 2,
            "style": "slide"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 0.6,
        "easing": "InOutExpo"
    }
};
