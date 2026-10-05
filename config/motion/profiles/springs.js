.pragma library

// Physical springs with a little overshoot (macOS-like): windows and
// layers bounce in, leave quickly on a plain ease-in.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "springs",
    "label": "prefs.motion.profile.springs",
    "description": "prefs.motion.profile.springs.desc",
    "icon": "sparkle",
    "curves": {
        // Underdamped (damping ratio ~0.64): one soft overshoot.
        "springsBounce": {
            "type": "spring",
            "mass": 1,
            "stiffness": 200,
            "dampening": 18,
            "fallback": [0.34, 1.56, 0.64, 1.0]
        },
        // Near-critical: settles without a visible wobble.
        "springsSettle": {
            "type": "spring",
            "mass": 1,
            "stiffness": 240,
            "dampening": 28,
            "fallback": [0.22, 1.0, 0.36, 1.0]
        },
        "springsExit": {
            "type": "bezier",
            "points": [0.4, 0.0, 1.0, 1.0]
        },
        "springsQuick": {
            "type": "bezier",
            "points": [0.15, 0.0, 0.1, 1.0]
        }
    },
    "leaves": {
        "windows": {
            "curve": "springsBounce",
            "speed": 4.5,
            "style": "popin 80%"
        },
        "windowsOut": {
            "curve": "springsExit",
            "speed": 1.6,
            "style": "popin 85%"
        },
        "windowsMove": {
            "curve": "springsSettle",
            "speed": 4.5
        },
        "layers": {
            "curve": "springsBounce",
            "speed": 3.8,
            "style": "popin 90%"
        },
        "layersOut": {
            "curve": "springsExit",
            "speed": 1.4,
            "style": "fade"
        },
        "fade": {
            "curve": "springsQuick",
            "speed": 2.5
        },
        "fadeOut": {
            "curve": "springsExit",
            "speed": 1.6
        },
        "border": {
            "curve": "springsQuick",
            "speed": 4
        },
        "workspaces": {
            "curve": "springsSettle",
            "speed": 4,
            "style": "slide"
        },
        "specialWorkspace": {
            "curve": "springsBounce",
            "speed": 4,
            "style": "slidevert"
        }
    },
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 1.1,
        "easing": "OutBack"
    }
};
