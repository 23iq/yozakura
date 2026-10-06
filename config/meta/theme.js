.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/theme.js (see config/meta/Meta.js for
// the entry format). The settings schema (modules/settings/schema) wins for
// labels/descriptions/options of keys it declares.

var description = "Look of the whole shell: light/dark/OLED mode, fonts, roundness, animation speed, shadows and the surface variants (sr*: background, popup, bar, pane, focus, primary, ...) every container is drawn with.";

var COLOR = "Color spec: a palette role (e.g. \"primary\", \"surface\", \"overBackground\"), \"#rrggbb\"/\"#aarrggbb\", or either with an alpha suffix (\"surface@0.5\").";

var AUTO = {
    "value": -1,
    "label": "Auto"
};

var keys = {
    "oledMode": {
        "description": "Pure black backgrounds (dark mode only); good for OLED panels."
    },
    "lightMode": {
        "description": "Use the light variant of the generated palette."
    },
    "roundness": {
        "min": 0,
        "max": 24,
        "unit": "px",
        "description": "Corner radius base for every surface (0 = square)."
    },
    "font": {
        "format": "font-family",
        "description": "UI font family (any installed family name)."
    },
    "fontSize": {
        "min": 8,
        "max": 32,
        "unit": "px",
        "description": "Base UI font size; other sizes scale from it."
    },
    "monoFont": {
        "format": "font-family",
        "description": "Monospace font family (terminal-like widgets, code)."
    },
    "monoFontSize": {
        "min": 8,
        "max": 32,
        "unit": "px",
        "description": "Monospace font size."
    },
    "tintIcons": {
        "description": "Tint app icons with the palette (monochrome look)."
    },
    "enableCorners": {
        "description": "Draw rounded screen corners."
    },
    "animDuration": {
        "min": 0,
        "max": 2000,
        "unit": "ms",
        "description": "Base animation duration; 0 disables animations."
    },
    "paletteTransitionDuration": {
        "min": 0,
        "max": 5000,
        "unit": "ms",
        "description": "Cross-fade time when the palette changes (wallpaper/scheme switch)."
    },
    "shadowOpacity": {
        "min": 0,
        "max": 1,
        "description": "Opacity of the shadow under shell surfaces."
    },
    "shadowColor": {
        "format": "color",
        "description": "Shadow color. " + COLOR
    },
    "shadowXOffset": {
        "min": -50,
        "max": 50,
        "unit": "px",
        "description": "Horizontal shadow offset."
    },
    "shadowYOffset": {
        "min": -50,
        "max": 50,
        "unit": "px",
        "description": "Vertical shadow offset."
    },
    "shadowBlur": {
        "min": 0,
        "max": 1,
        "description": "Shadow softness (0 = hard, 1 = soft)."
    },
    "terminalOpacity": {
        "min": -1,
        "max": 1,
        "description": "Background opacity written to the generated terminal theme (kitty); -1 follows the srBg variant opacity."
    },
    "surfaceEffect": {
        "enum": Enums.surfaceEffects(),
        "description": "Signature texture on the shell's own surfaces (bar, notch, launcher, popups, dock, settings; never app windows): none, crt (scanlines, phosphor glow, vignette) or ink (sumi-e paper grain + brush-stroke highlights). Registry: modules/components/surfaceeffects/SurfaceEffects.js."
    },
    "surfaceEffectOptions": {
        "description": "Options of the surface effect (each effect reads the ones it uses)."
    },
    "surfaceEffectOptions.intensity": {
        "min": 0,
        "max": 1,
        "description": "Strength of the surface effect 0..1; lowered automatically when needed to keep surface text at WCAG AA."
    },
    "surfaceEffectOptions.flicker": {
        "description": "crt: short phosphor flicker when a surface appears (none when animations are off)."
    },
    "surfaceEffectOptions.grain": {
        "min": 0,
        "max": 1,
        "description": "ink: amount of paper grain (full on light surfaces, faint on dark ones)."
    },
    "surfaceEffectOptions.brushHighlights": {
        "description": "ink: paint selection/focus highlights and active pills as brush strokes."
    },
    "glass": {
        "description": "Glass system (modules/theme/GlassModel.js): one master amount makes every surface more or less glassy; -1 anywhere means inherit/auto."
    },
    "glass.enabled": {
        "description": "Apply the glass system (off = the preset's surfaces exactly as designed)."
    },
    "glass.amount": {
        "min": 0,
        "max": 1,
        "special": [AUTO],
        "description": "Master glassiness 0 (solid) .. 1 (very glassy); -1 = the preset's own amount (its look unchanged)."
    },
    "glass.referenceAmount": {
        "min": 0,
        "max": 1,
        "special": [AUTO],
        "description": "Amount at which the preset shows its designed values; -1 = derived from the preset's sr*/terminal opacities."
    },
    "glass.advanced": {
        "description": "Advanced overrides of single glass properties; -1 = follow the master amount."
    },
    "glass.advanced.*": {
        "special": [AUTO],
        "description": "Override of this glass property; -1 = follow the master amount."
    },
    "glass.surfaces": {
        "description": "Per-surface glass amounts; -1 = the master amount."
    },
    "glass.surfaces.*": {
        "description": "Glass overrides of this surface."
    },
    "glass.surfaces.*.amount": {
        "min": 0,
        "max": 1,
        "special": [AUTO],
        "description": "Glass amount of this surface 0..1; -1 = inherit the master amount."
    },
    "glass.surfaces.windows.*Opacity": {
        "min": 0.3,
        "max": 1,
        "special": [AUTO],
        "description": "Window opacity set on the compositor; -1 = derived from the glass amount."
    },
    "sr*": {
        "description": "Surface variant: how containers of this kind are painted (gradient, border, content color, opacity)."
    },
    "sr*.label": {
        "readOnly": true,
        "description": "Display name of the variant (not user-editable)."
    },
    "sr*.gradient": {
        "format": "gradient",
        "description": "Gradient stops as [[colorSpec, position 0..1], ...]; a single stop is a flat color. " + COLOR
    },
    "sr*.gradientType": {
        "enum": Enums.GRADIENT_TYPES,
        "description": "How the gradient is drawn."
    },
    "sr*.gradientAngle": {
        "min": 0,
        "max": 360,
        "unit": "deg",
        "description": "Angle of a linear gradient."
    },
    "sr*.gradientCenterX": {
        "min": 0,
        "max": 1,
        "description": "Horizontal center of a radial gradient (0..1)."
    },
    "sr*.gradientCenterY": {
        "min": 0,
        "max": 1,
        "description": "Vertical center of a radial gradient (0..1)."
    },
    "sr*.halftoneDotMin": {
        "min": 0,
        "max": 20,
        "unit": "px",
        "description": "Smallest dot of the halftone pattern."
    },
    "sr*.halftoneDotMax": {
        "min": 0,
        "max": 20,
        "unit": "px",
        "description": "Largest dot of the halftone pattern."
    },
    "sr*.halftoneStart": {
        "min": 0,
        "max": 1,
        "description": "Where the halftone ramp starts (0..1 across the surface)."
    },
    "sr*.halftoneEnd": {
        "min": 0,
        "max": 1,
        "description": "Where the halftone ramp ends (0..1 across the surface)."
    },
    "sr*.halftoneDotColor": {
        "format": "color",
        "description": "Halftone dot color. " + COLOR
    },
    "sr*.halftoneBackgroundColor": {
        "format": "color",
        "description": "Color behind the halftone dots. " + COLOR
    },
    "sr*.border": {
        "format": "border",
        "description": "Border as [colorSpec, width px]; width 0 hides it. " + COLOR
    },
    "sr*.itemColor": {
        "format": "color",
        "description": "Color of text and icons drawn on this surface. " + COLOR
    },
    "sr*.opacity": {
        "min": 0,
        "max": 1,
        "description": "Surface opacity (lower = more see-through)."
    },
    "srFrame.inheritBg": {
        "description": "Paint the screen frame with the srBg variant instead of its own settings."
    },
    "density": {
        "enum": ["compact", "cozy", "roomy"],
        "description": "Size density of bar, notch, dock and panels: compact, cozy (the historical sizes) or roomy."
    },
    "shape": {
        "description": "Corner shape of the shell's surfaces."
    },
    "shape.corners": {
        "enum": ["round", "squircle", "cut", "tab"],
        "description": "Corner style of surfaces: round, squircle (smooth superellipse), cut (chamfered) or tab (popups square the corners on their anchor edge)."
    },
    "shape.popupCorners": {
        "enum": ["", "round", "squircle", "cut", "tab"],
        "description": "Corner style of popups and menus; empty follows shape.corners."
    },
    "shape.cutSize": {
        "min": 2,
        "max": 32,
        "unit": "px",
        "description": "Chamfer size of cut corners."
    },
    "icons": {
        "description": "Icon font settings."
    },
    "icons.weight": {
        "enum": ["regular", "bold", "fill"],
        "description": "Weight of the Phosphor icon font: regular (thin strokes), bold (default) or fill (solid glyphs)."
    },
    "type": {
        "description": "Type roles: heading font and case. Body text uses theme.font."
    },
    "type.heading": {
        "description": "Font family of page, section and panel titles; empty uses theme.font."
    },
    "type.headingCase": {
        "enum": ["none", "upper", "lower", "title"],
        "description": "Letter case applied to titles: none, upper, lower or title."
    },
    "popup": {
        "description": "Bar popups and menus: entry motion, tail and gap."
    },
    "popup.entry": {
        "enum": ["fade-scale", "slide-from-anchor", "morph-from-bar", "unfold"],
        "description": "How popups appear: fade and scale, slide out of the anchor, morph out of the bar or unfold."
    },
    "popup.tail": {
        "description": "Draw a small tail on popups pointing at the item that opened them."
    },
    "popup.gap": {
        "min": 0,
        "max": 32,
        "unit": "px",
        "description": "Distance between a popup and the item that opened it."
    },
    "signatures": {
        "description": "Decorative signatures drawn on top of the shell's surfaces."
    },
    "signatures.brushHighlight": {
        "description": "Paint selection and focus highlights as a brush stroke."
    },
    "signatures.petals": {
        "description": "Drift sakura petals across the shell's surfaces."
    }
};
