.pragma library

// Fast and crisp: strong ease-out, small scale, short durations.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "snappy",
    "label": "prefs.motion.profile.snappy",
    "description": "prefs.motion.profile.snappy.desc",
    "icon": "lightning",
    "curves": {
        "snappyOut": {
            "type": "bezier",
            "points": [0.2, 0.9, 0.1, 1.0]
        },
        "snappyIn": {
            "type": "bezier",
            "points": [0.5, 0.0, 0.9, 0.4]
        }
    },
    "leaves": {
        "windows": {
            "curve": "snappyOut",
            "speed": 2,
            "style": "popin 90%"
        },
        "windowsOut": {
            "curve": "snappyIn",
            "speed": 1.2,
            "style": "popin 90%"
        },
        "layers": {
            "curve": "snappyOut",
            "speed": 1.6,
            "style": "popin 95%"
        },
        "fade": {
            "curve": "snappyOut",
            "speed": 1.5
        },
        "border": {
            "curve": "snappyOut",
            "speed": 2
        },
        "workspaces": {
            "curve": "snappyOut",
            "speed": 2,
            "style": "slide"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 0.7,
        "easing": "OutQuart"
    }
};
