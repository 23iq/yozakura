.pragma library

// Sakura Glass: petals that overshoot as they land, a slow looping border
// gradient. Reproduces exactly the animation state that the hand-written
// ~/.config/hypr/custom/sakura.lua produced on top of the generated config
// and the end-4 base (`hyprctl animations` was used as the reference), so
// that file's animation block is no longer needed.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "sakura",
    "label": "prefs.motion.profile.sakura",
    "description": "prefs.motion.profile.sakura.desc",
    "icon": "flowArrow",
    "curves": {
        "sakuraOvershoot": {
            "type": "bezier",
            "points": [0.05, 0.9, 0.1, 1.08]
        },
        "sakuraSmoothOut": {
            "type": "bezier",
            "points": [0.36, 0.0, 0.66, -0.56]
        },
        "sakuraEase": {
            "type": "bezier",
            "points": [0.25, 0.1, 0.25, 1.0]
        },
        "sakuraLinear": {
            "type": "bezier",
            "points": [0.0, 0.0, 1.0, 1.0]
        },
        "sakuraStandard": {
            "type": "bezier",
            "points": [0.4, 0.0, 0.2, 1.0]
        },
        "sakuraDecel": {
            "type": "bezier",
            "points": [0.05, 0.7, 0.1, 1.0]
        },
        "sakuraAccel": {
            "type": "bezier",
            "points": [0.3, 0.0, 0.8, 0.15]
        },
        "sakuraMenuDecel": {
            "type": "bezier",
            "points": [0.1, 1.0, 0.0, 1.0]
        },
        "sakuraMenuAccel": {
            "type": "bezier",
            "points": [0.52, 0.03, 0.72, 0.08]
        },
        "sakuraStall": {
            "type": "bezier",
            "points": [1.0, -0.1, 0.7, 0.85]
        }
    },
    "leaves": {
        "windows": {
            "curve": "sakuraStandard",
            "speed": 2.5,
            "style": "popin 80%"
        },
        "windowsIn": {
            "curve": "sakuraOvershoot",
            "speed": 4,
            "style": "popin 85%"
        },
        "windowsOut": {
            "curve": "sakuraSmoothOut",
            "speed": 3,
            "style": "popin 85%"
        },
        "windowsMove": {
            "curve": "sakuraOvershoot",
            "speed": 4
        },
        "layersIn": {
            "curve": "sakuraDecel",
            "speed": 2.7,
            "style": "popin 93%"
        },
        "layersOut": {
            "curve": "sakuraMenuAccel",
            "speed": 2.4,
            "style": "popin 94%"
        },
        "fade": {
            "curve": "sakuraStandard",
            "speed": 2.5
        },
        "fadeIn": {
            "curve": "sakuraEase",
            "speed": 3
        },
        "fadeOut": {
            "curve": "sakuraDecel",
            "speed": 2
        },
        "fadeLayersIn": {
            "curve": "sakuraMenuDecel",
            "speed": 0.5
        },
        "fadeLayersOut": {
            "curve": "sakuraStall",
            "speed": 2.7
        },
        "border": {
            "curve": "sakuraEase",
            "speed": 6
        },
        "workspaces": {
            "curve": "sakuraStandard",
            "speed": 2.5,
            "style": "slidefade 20%"
        },
        "specialWorkspaceIn": {
            "curve": "sakuraDecel",
            "speed": 2.8,
            "style": "slidevert"
        },
        "specialWorkspaceOut": {
            "curve": "sakuraAccel",
            "speed": 1.2,
            "style": "slidevert"
        }
    },
    // Slow looping gradient rotation; 100 is the slowest speed Hyprland takes.
    "borderLoop": {
        "enabled": true,
        "speed": 100,
        "curve": "sakuraLinear"
    },
    "shell": {
        "scale": 1.0,
        "easing": "OutCubic"
    }
};
