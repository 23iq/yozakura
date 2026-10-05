.pragma library
.import "motion.js" as Motion

// Windows: the compositor (Hyprland) appearance - layout, gaps, borders
// (palette roles, gradients, music-reactive pulse), rounding, dimming,
// shadows, blur - plus the motion profile (motion.js).
// Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "windows",
    "icon": "compositor",
    "title": "prefs.cat.windows",
    "description": "prefs.cat.windows.desc",
    "keywords": "windows compositor hyprland gaps borders rounding blur shadows dim layout tiling motion animations",
    "sections": [
        {
            "id": "layout",
            "title": "prefs.windows.section.layout",
            "entries": [
                {
                    "key": "compositor.layout",
                    "type": "selector",
                    "options": [
                        {
                            "value": "dwindle",
                            "label": "compositor.layout.dwindle",
                            "icon": "dwindle"
                        },
                        {
                            "value": "master",
                            "label": "compositor.layout.master",
                            "icon": "master"
                        },
                        {
                            "value": "scrolling",
                            "label": "compositor.layout.scrolling",
                            "icon": "scrolling"
                        }
                    ],
                    "preview": "WindowsPreview",
                    "label": "prefs.windows.layout",
                    "description": "prefs.windows.layout.desc",
                    "keywords": "layout tiling dwindle master scrolling preview windows"
                },
                {
                    "key": "compositor.gapsIn",
                    "type": "slider",
                    "min": 0,
                    "max": 50,
                    "step": 1,
                    "unit": "px",
                    "label": "prefs.windows.gaps_in",
                    "description": "prefs.windows.gaps_in.desc",
                    "keywords": "gaps inner spacing between windows padding"
                },
                {
                    "key": "compositor.gapsOut",
                    "type": "slider",
                    "min": 0,
                    "max": 100,
                    "step": 1,
                    "unit": "px",
                    "label": "prefs.windows.gaps_out",
                    "description": "prefs.windows.gaps_out.desc",
                    "keywords": "gaps outer margin screen edges padding"
                },
                {
                    "key": "compositor.smartGaps",
                    "type": "toggle",
                    "label": "prefs.windows.smart_gaps",
                    "description": "prefs.windows.smart_gaps.desc",
                    "keywords": "smart gaps single window no gaps lone fullscreen-like"
                }
            ]
        },
        {
            "id": "borders",
            "title": "prefs.windows.section.borders",
            "entries": [
                {
                    "key": "compositor.syncBorderWidth",
                    "type": "toggle",
                    "label": "prefs.windows.sync_border_width",
                    "description": "prefs.windows.sync_border_width.desc",
                    "keywords": "sync border width shell"
                },
                {
                    "key": "compositor.borderSize",
                    "type": "slider",
                    "min": 0,
                    "max": 20,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "compositor.syncBorderWidth",
                        "equals": false
                    },
                    "label": "prefs.windows.border_size",
                    "description": "prefs.windows.border_size.desc",
                    "keywords": "border width thickness stroke"
                },
                {
                    "key": "compositor.syncBorderColor",
                    "type": "toggle",
                    "label": "prefs.windows.sync_border_color",
                    "description": "prefs.windows.sync_border_color.desc",
                    "keywords": "sync border color accent shell"
                },
                {
                    "key": "compositor.activeBorderColor",
                    "type": "color-role",
                    "gradient": true,
                    "visibleWhen": {
                        "key": "compositor.syncBorderColor",
                        "equals": false
                    },
                    "label": "prefs.windows.active_border",
                    "description": "prefs.windows.active_border.desc",
                    "keywords": "active focused border color gradient role palette alpha"
                },
                {
                    "key": "compositor.borderAngle",
                    "type": "slider",
                    "min": 0,
                    "max": 360,
                    "step": 5,
                    "unit": "deg",
                    "label": "prefs.windows.border_angle",
                    "description": "prefs.windows.border_angle.desc",
                    "keywords": "gradient angle rotation border"
                },
                {
                    "key": "compositor.inactiveBorderColor",
                    "type": "color-role",
                    "gradient": true,
                    "label": "prefs.windows.inactive_border",
                    "description": "prefs.windows.inactive_border.desc",
                    "keywords": "inactive unfocused border color gradient role palette alpha"
                },
                {
                    "key": "compositor.inactiveBorderAngle",
                    "type": "slider",
                    "min": 0,
                    "max": 360,
                    "step": 5,
                    "unit": "deg",
                    "label": "prefs.windows.inactive_border_angle",
                    "description": "prefs.windows.inactive_border_angle.desc",
                    "keywords": "gradient angle inactive border"
                },
                {
                    "key": "compositor.borderPulse.enabled",
                    "type": "toggle",
                    "label": "prefs.windows.border_pulse",
                    "description": "prefs.windows.border_pulse.desc",
                    "keywords": "music reactive border pulse beat audio cava visualizer neon glow"
                },
                {
                    "key": "compositor.borderPulse.intensity",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.borderPulse.enabled",
                        "equals": true
                    },
                    "label": "prefs.windows.border_pulse_intensity",
                    "description": "prefs.windows.border_pulse_intensity.desc",
                    "keywords": "pulse intensity strength music border"
                }
            ]
        },
        {
            "id": "shape",
            "title": "prefs.windows.section.shape",
            "entries": [
                {
                    "key": "compositor.syncRoundness",
                    "type": "toggle",
                    "label": "prefs.windows.sync_rounding",
                    "description": "prefs.windows.sync_rounding.desc",
                    "keywords": "sync rounding roundness corners shell theme"
                },
                {
                    "key": "compositor.rounding",
                    "type": "slider",
                    "min": 0,
                    "max": 40,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "compositor.syncRoundness",
                        "equals": false
                    },
                    "label": "prefs.windows.rounding",
                    "description": "prefs.windows.rounding.desc",
                    "keywords": "rounding radius corners round"
                },
                {
                    "key": "compositor.dimInactive",
                    "type": "toggle",
                    "label": "prefs.windows.dim_inactive",
                    "description": "prefs.windows.dim_inactive.desc",
                    "keywords": "dim inactive unfocused darken focus"
                },
                {
                    "key": "compositor.dimStrength",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.01,
                    "visibleWhen": {
                        "key": "compositor.dimInactive",
                        "equals": true
                    },
                    "label": "prefs.windows.dim_strength",
                    "description": "prefs.windows.dim_strength.desc",
                    "keywords": "dim strength amount darken"
                }
            ]
        },
        {
            "id": "shadows",
            "title": "prefs.windows.section.shadows",
            "entries": [
                {
                    "key": "compositor.shadowEnabled",
                    "type": "toggle",
                    "label": "prefs.windows.shadows",
                    "description": "prefs.windows.shadows.desc",
                    "keywords": "shadow drop shadows glow"
                },
                {
                    "key": "compositor.shadowRange",
                    "type": "slider",
                    "min": 0,
                    "max": 100,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_range",
                    "description": "prefs.windows.shadow_range.desc",
                    "keywords": "shadow size range blur radius softness"
                },
                {
                    "key": "compositor.syncShadowColor",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.sync_shadow_color",
                    "description": "prefs.windows.sync_shadow_color.desc",
                    "keywords": "sync shadow color theme"
                },
                {
                    "key": "compositor.shadowColor",
                    "type": "color-role",
                    "visibleWhen": {
                        "all": [
                            {
                                "key": "compositor.shadowEnabled",
                                "equals": true
                            },
                            {
                                "key": "compositor.syncShadowColor",
                                "equals": false
                            }
                        ]
                    },
                    "label": "prefs.windows.shadow_color",
                    "description": "prefs.windows.shadow_color.desc",
                    "keywords": "shadow color glow focused role palette"
                },
                {
                    "key": "compositor.syncShadowOpacity",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.sync_shadow_opacity",
                    "description": "prefs.windows.sync_shadow_opacity.desc",
                    "keywords": "sync shadow opacity theme"
                },
                {
                    "key": "compositor.shadowOpacity",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "all": [
                            {
                                "key": "compositor.shadowEnabled",
                                "equals": true
                            },
                            {
                                "key": "compositor.syncShadowOpacity",
                                "equals": false
                            }
                        ]
                    },
                    "label": "prefs.windows.shadow_opacity",
                    "description": "prefs.windows.shadow_opacity.desc",
                    "keywords": "shadow opacity darkness alpha"
                }
            ]
        },
        {
            "id": "shadowsAdvanced",
            "title": "prefs.windows.section.shadows_advanced",
            "collapsible": true,
            "collapsed": true,
            "entries": [
                {
                    "key": "compositor.shadowColorInactive",
                    "type": "color-role",
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_color_inactive",
                    "description": "prefs.windows.shadow_color_inactive.desc",
                    "keywords": "shadow color inactive unfocused"
                },
                {
                    "key": "compositor.shadowRenderPower",
                    "type": "slider",
                    "min": 1,
                    "max": 4,
                    "step": 1,
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_power",
                    "description": "prefs.windows.shadow_power.desc",
                    "keywords": "shadow falloff power render"
                },
                {
                    "key": "compositor.shadowScale",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_scale",
                    "description": "prefs.windows.shadow_scale.desc",
                    "keywords": "shadow scale size"
                },
                {
                    "key": "compositor.shadowOffset",
                    "type": "text",
                    "placeholder": "prefs.windows.shadow_offset.placeholder",
                    "monospace": true,
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_offset",
                    "description": "prefs.windows.shadow_offset.desc",
                    "keywords": "shadow offset position x y move"
                },
                {
                    "key": "compositor.shadowSharp",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.shadowEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.shadow_sharp",
                    "description": "prefs.windows.shadow_sharp.desc",
                    "keywords": "shadow sharp hard edge"
                }
            ]
        },
        {
            "id": "blur",
            "title": "prefs.windows.section.blur",
            "entries": [
                {
                    "id": "windows.glassLink",
                    "type": "custom",
                    "component": "PageLink",
                    "target": "appearance",
                    "targetSection": "glass",
                    "linkText": "prefs.windows.glass_link.open",
                    "label": "prefs.windows.glass_link",
                    "description": "prefs.windows.glass_link.desc",
                    "keywords": "glass blur amount transparency translucent frosted"
                },
                {
                    "key": "compositor.blurEnabled",
                    "type": "toggle",
                    "label": "prefs.windows.blur",
                    "description": "prefs.windows.blur.desc",
                    "keywords": "blur frosted glass transparency behind windows"
                },
                {
                    "key": "compositor.blurSize",
                    "type": "slider",
                    "min": 0,
                    "max": 20,
                    "step": 1,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_size",
                    "description": "prefs.windows.blur_size.desc",
                    "keywords": "blur size radius amount"
                },
                {
                    "key": "compositor.blurPasses",
                    "type": "slider",
                    "min": 1,
                    "max": 10,
                    "step": 1,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_passes",
                    "description": "prefs.windows.blur_passes.desc",
                    "keywords": "blur passes quality iterations"
                },
                {
                    "key": "compositor.blurVibrancy",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_vibrancy",
                    "description": "prefs.windows.blur_vibrancy.desc",
                    "keywords": "blur vibrancy saturation color"
                },
                {
                    "key": "compositor.blurXray",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_xray",
                    "description": "prefs.windows.blur_xray.desc",
                    "keywords": "blur xray see through wallpaper floating"
                },
                {
                    "key": "compositor.blurPopups",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_popups",
                    "description": "prefs.windows.blur_popups.desc",
                    "keywords": "blur popups menus context"
                }
            ]
        },
        {
            "id": "blurAdvanced",
            "title": "prefs.windows.section.blur_advanced",
            "collapsible": true,
            "collapsed": true,
            "entries": [
                {
                    "key": "compositor.blurNoise",
                    "type": "slider",
                    "min": 0,
                    "max": 0.2,
                    "step": 0.005,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_noise",
                    "description": "prefs.windows.blur_noise.desc",
                    "keywords": "blur noise grain"
                },
                {
                    "key": "compositor.blurContrast",
                    "type": "slider",
                    "min": 0,
                    "max": 2,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_contrast",
                    "description": "prefs.windows.blur_contrast.desc",
                    "keywords": "blur contrast"
                },
                {
                    "key": "compositor.blurBrightness",
                    "type": "slider",
                    "min": 0,
                    "max": 2,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_brightness",
                    "description": "prefs.windows.blur_brightness.desc",
                    "keywords": "blur brightness light"
                },
                {
                    "key": "compositor.blurVibrancyDarkness",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_vibrancy_darkness",
                    "description": "prefs.windows.blur_vibrancy_darkness.desc",
                    "keywords": "blur vibrancy darkness dark colors"
                },
                {
                    "key": "compositor.blurSpecial",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_special",
                    "description": "prefs.windows.blur_special.desc",
                    "keywords": "blur special workspace scratchpad"
                },
                {
                    "key": "compositor.blurIgnoreOpacity",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_ignore_opacity",
                    "description": "prefs.windows.blur_ignore_opacity.desc",
                    "keywords": "blur ignore opacity"
                },
                {
                    "key": "compositor.blurNewOptimizations",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_new_optimizations",
                    "description": "prefs.windows.blur_new_optimizations.desc",
                    "keywords": "blur optimizations performance"
                },
                {
                    "key": "compositor.blurExplicitIgnoreAlpha",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_ignore_alpha",
                    "description": "prefs.windows.blur_ignore_alpha.desc",
                    "keywords": "blur ignore alpha threshold transparent pixels"
                },
                {
                    "key": "compositor.blurIgnoreAlphaValue",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "all": [
                            {
                                "key": "compositor.blurEnabled",
                                "equals": true
                            },
                            {
                                "key": "compositor.blurExplicitIgnoreAlpha",
                                "equals": true
                            }
                        ]
                    },
                    "label": "prefs.windows.blur_ignore_alpha_value",
                    "description": "prefs.windows.blur_ignore_alpha_value.desc",
                    "keywords": "blur alpha threshold"
                },
                {
                    "key": "compositor.blurPopupsIgnorealpha",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "all": [
                            {
                                "key": "compositor.blurEnabled",
                                "equals": true
                            },
                            {
                                "key": "compositor.blurPopups",
                                "equals": true
                            }
                        ]
                    },
                    "label": "prefs.windows.blur_popups_ignorealpha",
                    "description": "prefs.windows.blur_popups_ignorealpha.desc",
                    "keywords": "blur popups alpha threshold"
                },
                {
                    "key": "compositor.blurInputMethods",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "compositor.blurEnabled",
                        "equals": true
                    },
                    "label": "prefs.windows.blur_input_methods",
                    "description": "prefs.windows.blur_input_methods.desc",
                    "keywords": "blur input method ime popup"
                },
                {
                    "key": "compositor.blurInputMethodsIgnorealpha",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "all": [
                            {
                                "key": "compositor.blurEnabled",
                                "equals": true
                            },
                            {
                                "key": "compositor.blurInputMethods",
                                "equals": true
                            }
                        ]
                    },
                    "label": "prefs.windows.blur_input_methods_ignorealpha",
                    "description": "prefs.windows.blur_input_methods_ignorealpha.desc",
                    "keywords": "blur input method alpha threshold"
                }
            ]
        }
    ].concat(Motion.sections)
};
