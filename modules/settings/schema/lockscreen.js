.pragma library

// Lockscreen & Login: the lock screen style gallery (live previews from the
// real lock screen), tone, layout, media, and the SDDM login theme that
// mirrors the lock screen. Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "lockscreen",
    "icon": "lock",
    "title": "prefs.cat.lockscreen",
    "description": "prefs.cat.lockscreen.desc",
    "keywords": "lock screen login password greeter sddm style",
    "stage": "LockStage",
    "hero": {
        "right": ["lockscreen.showStatus", "lockscreen.showMedia", "lockscreen.showVisualizer"],
        "hint": "prefs.lockscreen.hero_hint"
    },
    "row": ["style", "layout"],
    "sections": [
        {
            "id": "style",
            "title": "prefs.lockscreen.section.style",
            "entries": [
                {
                    "key": "lockscreen.style",
                    "type": "custom",
                    "component": "LockStyleGallery",
                    "label": "prefs.lockscreen.style",
                    "description": "prefs.lockscreen.style.desc",
                    "keywords": "lock screen style look glass paper sumi-e terminal crt aurora glacier neon tokyo poster koyo"
                },
                {
                    "key": "lockscreen.tone",
                    "type": "selector",
                    "options": [
                        {
                            "value": "style",
                            "label": "prefs.lockscreen.tone.style",
                            "icon": "paintBrush"
                        },
                        {
                            "value": "theme",
                            "label": "prefs.lockscreen.tone.theme",
                            "icon": "circleHalf"
                        },
                        {
                            "value": "light",
                            "label": "prefs.lockscreen.tone.light",
                            "icon": "sun"
                        },
                        {
                            "value": "dark",
                            "label": "prefs.lockscreen.tone.dark",
                            "icon": "moon"
                        }
                    ],
                    "visibleWhen": {
                        "key": "lockscreen.style",
                        "notEquals": "neon"
                    },
                    "label": "prefs.lockscreen.tone",
                    "description": "prefs.lockscreen.tone.desc",
                    "keywords": "lock screen light dark tone mode theme"
                }
            ]
        },
        {
            "id": "layout",
            "title": "prefs.lockscreen.section.layout",
            "entries": [
                {
                    "key": "lockscreen.position",
                    "type": "selector",
                    "options": [
                        {
                            "value": "top",
                            "label": "common.top",
                            "icon": "arrowUp"
                        },
                        {
                            "value": "bottom",
                            "label": "common.bottom",
                            "icon": "arrowDown"
                        }
                    ],
                    "label": "prefs.lockscreen.position",
                    "description": "prefs.lockscreen.position.desc",
                    "keywords": "lock screen password position top bottom edge"
                },
                {
                    "key": "lockscreen.blur",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "specialValues": [
                        {
                            "value": -1,
                            "label": "prefs.lockscreen.blur.style"
                        },
                        {
                            "value": 0,
                            "label": "prefs.common.off"
                        }
                    ],
                    "label": "prefs.lockscreen.blur",
                    "description": "prefs.lockscreen.blur.desc",
                    "keywords": "lock screen wallpaper blur soft background"
                },
                {
                    "key": "lockscreen.showStatus",
                    "type": "toggle",
                    "label": "prefs.lockscreen.show_status",
                    "description": "prefs.lockscreen.show_status.desc",
                    "keywords": "lock screen status user network wifi battery"
                }
            ]
        },
        {
            "id": "media",
            "title": "prefs.lockscreen.section.media",
            "entries": [
                {
                    "key": "lockscreen.showMedia",
                    "type": "toggle",
                    "label": "prefs.lockscreen.show_media",
                    "description": "prefs.lockscreen.show_media.desc",
                    "keywords": "lock screen media music player now playing"
                },
                {
                    "key": "lockscreen.showVisualizer",
                    "type": "toggle",
                    "enabledWhen": {
                        "key": "lockscreen.showMedia",
                        "equals": true
                    },
                    "label": "prefs.lockscreen.show_visualizer",
                    "description": "prefs.lockscreen.show_visualizer.desc",
                    "keywords": "lock screen audio visualizer cava bars spectrum"
                }
            ]
        },
        {
            "id": "auth",
            "title": "prefs.lockscreen.section.auth",
            "entries": [
                {
                    "key": "lockscreen.pamService",
                    "advanced": true,
                    "type": "text",
                    "label": "prefs.lockscreen.pam_service",
                    "description": "prefs.lockscreen.pam_service.desc",
                    "keywords": "lock screen pam authentication service ldap sssd homed fingerprint fprintd u2f yubikey password unlock",
                    "placeholder": "prefs.lockscreen.pam_service.placeholder",
                    "pattern": "^$|^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}$",
                    // A page or section reset must not clear it: an account
                    // that only this service can verify would be locked out.
                    "resettable": false
                }
            ]
        },
        {
            "id": "login",
            "title": "prefs.lockscreen.section.login",
            "entries": [
                {
                    "id": "lockscreen.sddm",
                    "type": "custom",
                    "component": "LoginScreenCard",
                    "resettable": false,
                    "label": "prefs.lockscreen.sddm",
                    "description": "prefs.lockscreen.sddm.desc",
                    "keywords": "sddm login greeter display manager theme sync install"
                }
            ]
        }
    ]
};
