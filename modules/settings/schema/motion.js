.pragma library

// Windows > Motion: the motion profile (config/motion) and its per-part
// overrides (compositor.motion*). Spliced into windows.js.
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "motion",
        "title": "prefs.motion.section",
        "entries": [
            {
                "key": "compositor.motionProfile",
                "type": "custom",
                "component": "MotionProfileCards",
                "keys": [
                    "compositor.motionProfile"
                ],
                "label": "prefs.motion.profile",
                "description": "prefs.motion.profile.desc",
                "keywords": "motion animations profile springs smooth gentle stepped snappy off sakura bezier curve speed"
            },
            {
                "key": "compositor.motionDurationScale",
                "type": "slider",
                "min": 0.25,
                "max": 3,
                "step": 0.05,
                "unit": "×",
                "visibleWhen": {
                    "key": "compositor.motionProfile",
                    "notEquals": "off"
                },
                "label": "prefs.motion.duration_scale",
                "description": "prefs.motion.duration_scale.desc",
                "keywords": "animation speed duration slower faster scale"
            },
            {
                "key": "compositor.motionWorkspaceStyle",
                "type": "selector",
                "options": [
                    {
                        "value": "auto",
                        "label": "prefs.motion.workspace.auto"
                    },
                    {
                        "value": "slide",
                        "label": "prefs.motion.workspace.slide"
                    },
                    {
                        "value": "slidefade",
                        "label": "prefs.motion.workspace.slidefade"
                    },
                    {
                        "value": "fade",
                        "label": "prefs.motion.workspace.fade"
                    }
                ],
                "visibleWhen": {
                    "key": "compositor.motionProfile",
                    "notEquals": "off"
                },
                "label": "prefs.motion.workspace_style",
                "description": "prefs.motion.workspace_style.desc",
                "keywords": "workspace switch animation slide fade"
            },
            {
                "key": "compositor.motionBorderLoop",
                "type": "selector",
                "options": [
                    {
                        "value": "auto",
                        "label": "prefs.motion.loop.auto"
                    },
                    {
                        "value": "on",
                        "label": "prefs.motion.loop.on"
                    },
                    {
                        "value": "off",
                        "label": "prefs.motion.loop.off"
                    }
                ],
                "visibleWhen": {
                    "key": "compositor.motionProfile",
                    "notEquals": "off"
                },
                "label": "prefs.motion.border_loop",
                "description": "prefs.motion.border_loop.desc",
                "keywords": "border gradient rotate loop spin animation"
            },
            {
                "key": "compositor.motionBorderLoopSpeed",
                "type": "slider",
                "min": 0,
                "max": 100,
                "step": 1,
                "specialValues": [
                    {
                        "value": 0,
                        "label": "prefs.motion.loop.profile"
                    }
                ],
                "visibleWhen": {
                    "all": [
                        {
                            "key": "compositor.motionProfile",
                            "notEquals": "off"
                        },
                        {
                            "key": "compositor.motionBorderLoop",
                            "notEquals": "off"
                        }
                    ]
                },
                "label": "prefs.motion.border_loop_speed",
                "description": "prefs.motion.border_loop_speed.desc",
                "keywords": "border loop speed rotation period"
            },
            {
                "key": "compositor.motionShell",
                "type": "toggle",
                "label": "prefs.motion.shell",
                "description": "prefs.motion.shell.desc",
                "keywords": "shell animations speed easing follow profile"
            }
        ]
    }
];
