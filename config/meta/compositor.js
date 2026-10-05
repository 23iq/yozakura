.pragma library
.import "Enums.js" as Enums
.import "../motion/MotionProfiles.js" as MotionProfiles

// Catalog metadata of config/defaults/compositor.js (format: config/meta/Meta.js).
// These keys are written to the compositor (Hyprland/yozd) by
// modules/services/CompositorTomlWriter.qml.

var description = "Window manager appearance applied to the compositor: borders, gaps, rounding, layout, window shadows, blur, dimming, motion profile (animations) and the music-reactive border.";

var keys = {
    "activeBorderColor": {
        "items": {
            "type": "string"
        },
        "description": "Focused window border colors (color specs; several = gradient)."
    },
    "borderAngle": {
        "min": 0,
        "max": 360,
        "unit": "deg",
        "description": "Gradient angle of the focused window border."
    },
    "inactiveBorderColor": {
        "items": {
            "type": "string"
        },
        "description": "Unfocused window border colors (color specs)."
    },
    "inactiveBorderAngle": {
        "min": 0,
        "max": 360,
        "unit": "deg",
        "description": "Gradient angle of unfocused window borders."
    },
    "borderSize": {
        "min": 0,
        "max": 20,
        "unit": "px",
        "description": "Window border width."
    },
    "rounding": {
        "min": 0,
        "max": 40,
        "unit": "px",
        "description": "Window corner radius (ignored while syncRoundness is on)."
    },
    "syncRoundness": {
        "description": "Use theme.roundness for window corners."
    },
    "syncBorderWidth": {
        "description": "Use the shell border width for windows."
    },
    "syncBorderColor": {
        "description": "Use the shell accent for window borders."
    },
    "syncShadowOpacity": {
        "description": "Use theme.shadowOpacity for window shadows."
    },
    "syncShadowColor": {
        "description": "Use theme.shadowColor for window shadows."
    },
    "gapsIn": {
        "min": 0,
        "max": 50,
        "unit": "px",
        "description": "Gap between windows."
    },
    "gapsOut": {
        "min": 0,
        "max": 100,
        "unit": "px",
        "description": "Gap between windows and screen edges."
    },
    "layout": {
        "enum": Enums.COMPOSITOR_LAYOUTS,
        "description": "Tiling layout."
    },
    "shadowEnabled": {
        "description": "Window shadows."
    },
    "shadowRange": {
        "min": 0,
        "max": 100,
        "unit": "px",
        "description": "Window shadow size."
    },
    "shadowRenderPower": {
        "min": 1,
        "max": 4,
        "description": "Window shadow falloff (1..4)."
    },
    "shadowSharp": {
        "description": "Hard-edged window shadows."
    },
    "shadowIgnoreWindow": {
        "description": "Do not draw the shadow behind the window itself."
    },
    "shadowColor": {
        "format": "color",
        "description": "Focused window shadow color (color spec)."
    },
    "shadowColorInactive": {
        "format": "color",
        "description": "Unfocused window shadow color (color spec)."
    },
    "shadowOpacity": {
        "min": 0,
        "max": 1,
        "description": "Window shadow opacity."
    },
    "shadowOffset": {
        "pattern": "^-?\\d+(\\.\\d+)? -?\\d+(\\.\\d+)?$",
        "description": "Window shadow offset \"x y\" in px."
    },
    "shadowScale": {
        "min": 0,
        "max": 1,
        "description": "Window shadow scale."
    },
    "blurEnabled": {
        "description": "Blur behind translucent windows and shell surfaces."
    },
    "blurSize": {
        "min": 0,
        "max": 20,
        "description": "Blur radius."
    },
    "blurPasses": {
        "min": 0,
        "max": 10,
        "description": "Blur passes (more = smoother, slower)."
    },
    "blurIgnoreOpacity": {
        "description": "Blur regardless of window opacity."
    },
    "blurExplicitIgnoreAlpha": {
        "description": "Skip blurring pixels below blurIgnoreAlphaValue."
    },
    "blurIgnoreAlphaValue": {
        "min": 0,
        "max": 1,
        "description": "Alpha threshold for blurExplicitIgnoreAlpha."
    },
    "blurNewOptimizations": {
        "description": "Compositor blur optimizations."
    },
    "blurXray": {
        "description": "Floating windows blur only the wallpaper (x-ray)."
    },
    "blurNoise": {
        "min": 0,
        "max": 1,
        "description": "Noise added to the blur."
    },
    "blurContrast": {
        "min": 0,
        "max": 2,
        "description": "Blur contrast."
    },
    "blurBrightness": {
        "min": 0,
        "max": 2,
        "description": "Blur brightness."
    },
    "blurVibrancy": {
        "min": 0,
        "max": 1,
        "description": "Blur saturation boost."
    },
    "blurVibrancyDarkness": {
        "min": 0,
        "max": 1,
        "description": "Vibrancy strength on dark colors."
    },
    "blurSpecial": {
        "description": "Blur behind special workspaces."
    },
    "blurPopups": {
        "description": "Blur behind popups."
    },
    "blurPopupsIgnorealpha": {
        "min": 0,
        "max": 1,
        "description": "Alpha threshold for popup blur."
    },
    "blurInputMethods": {
        "description": "Blur behind input-method popups."
    },
    "blurInputMethodsIgnorealpha": {
        "min": 0,
        "max": 1,
        "description": "Alpha threshold for input-method blur."
    },
    "smartGaps": {
        "description": "No gaps on a workspace with a single tiled window."
    },
    "dimInactive": {
        "description": "Dim unfocused windows."
    },
    "dimStrength": {
        "min": 0,
        "max": 1,
        "description": "How much unfocused windows are dimmed."
    },
    "motionProfile": {
        "enum": MotionProfiles.ids(),
        "description": "Motion profile (config/motion/profiles): the compositor animations (curves, window/layer/workspace/fade/border animations, border gradient loop) and, with motionShell, the shell animation scale and easing."
    },
    "motionDurationScale": {
        "min": 0.25,
        "max": 3,
        "description": "Multiplies every animation duration of the profile (1 = as designed)."
    },
    "motionWorkspaceStyle": {
        "enum": ["auto", "slide", "slidefade", "fade"],
        "description": "Workspace switch animation; auto = the profile's. Slides run along the bar (vertical bar = vertical slide)."
    },
    "motionBorderLoop": {
        "enum": ["auto", "on", "off"],
        "description": "Looping rotation of gradient window borders; auto = the profile's."
    },
    "motionBorderLoopSpeed": {
        "min": 0,
        "max": 100,
        "special": [{
                "value": 0,
                "label": "Profile"
            }],
        "description": "Border loop period in Hyprland speed units (1 = 100 ms, 100 = slowest); 0 = the profile's."
    },
    "motionShell": {
        "description": "The motion profile also sets the shell's animation speed and easing."
    },
    "motionOverrides": {
        "description": "Per-animation overrides on top of the profile: {node: {enabled, speed, curve, style}} where node is a Hyprland animation (windowsIn, windowsOut, windowsMove, layersIn, layersOut, fadeIn, fadeOut, border, borderangle, workspaces, specialWorkspace, ...; children inherit from parents), speed is in Hyprland units (1 = 100 ms), curve is a curve name of the profile or [x0, y0, x1, y1], style e.g. \"popin 80%\"."
    },
    "borderPulse.enabled": {
        "description": "Active window border pulses with the music (only while something is playing)."
    },
    "borderPulse.source": {
        "enum": ["cava"],
        "description": "Audio source of the border pulse."
    },
    "borderPulse.intensity": {
        "min": 0,
        "max": 1,
        "description": "How strongly the border pulses."
    }
};
