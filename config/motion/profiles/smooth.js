.pragma library

// The motion Yozakura always shipped: one standard ease-out curve, a short
// pop-in and a sliding fade between workspaces. Default profile.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "smooth",
    "label": "prefs.motion.profile.smooth",
    "description": "prefs.motion.profile.smooth.desc",
    "icon": "waveform",
    "curves": {
        "smoothStandard": {
            "type": "bezier",
            "points": [0.4, 0.0, 0.2, 1.0]
        }
    },
    "leaves": {
        "windows": {
            "curve": "smoothStandard",
            "speed": 2.5,
            "style": "popin 80%"
        },
        "border": {
            "curve": "smoothStandard",
            "speed": 2.5
        },
        "fade": {
            "curve": "smoothStandard",
            "speed": 2.5
        },
        "workspaces": {
            "curve": "smoothStandard",
            "speed": 2.5,
            "style": "slidefade 20%"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 1.0,
        "easing": "OutCubic"
    }
};
