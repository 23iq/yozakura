.pragma library

// No animations at all, in the compositor and in the shell.
// Format: config/motion/MotionProfiles.js.

var profile = {
    "id": "off",
    "label": "prefs.motion.profile.off",
    "description": "prefs.motion.profile.off.desc",
    "icon": "stopCircle",
    "disabled": true,
    "curves": {},
    "leaves": {},
    "borderLoop": {
        "enabled": false,
        "speed": 0
    },
    "shell": {
        "scale": 0,
        "easing": "Linear"
    }
};
