.pragma library
.import "../editors/surfaces/SurfaceRoles.js" as SurfaceRoles
.import "../../../config/defaults/theme.js" as ThemeDefaults

// Appearance > Surfaces: the sr* surface variants (fill, border, opacity,
// gradient/halftone) every shell container is drawn with, and the shadow
// under shell surfaces (theme.shadow*, distinct from the compositor's
// window shadows in windows.js). Spliced into appearance.js.
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "surfaces",
        "title": "prefs.surfaces.section",
        "entries": [
            {
                "id": "theme.surfaces",
                "type": "custom",
                "component": "SurfaceRolesEditor",
                "keys": SurfaceRoles.keys(ThemeDefaults.data),
                "advanced": true,
                "label": "prefs.surfaces.roles",
                "description": "prefs.surfaces.roles.desc",
                "keywords": "surface variant sr background popup pane bar frame focus primary secondary tertiary error fill gradient radial halftone dots border opacity item color container"
            }
        ]
    },
    {
        "id": "shellShadow",
        "title": "prefs.surfaces.section.shadow",
        "entries": [
            {
                "key": "theme.shadowColor",
                "type": "color-role",
                "label": "prefs.surfaces.shadow_color",
                "description": "prefs.surfaces.shadow_color.desc",
                "keywords": "shell shadow color glow palette role"
            },
            {
                "key": "theme.shadowOpacity",
                "type": "slider",
                "min": 0,
                "max": 1,
                "step": 0.05,
                "label": "prefs.surfaces.shadow_opacity",
                "description": "prefs.surfaces.shadow_opacity.desc",
                "keywords": "shell shadow opacity darkness alpha strength"
            },
            {
                "key": "theme.shadowBlur",
                "type": "slider",
                "min": 0,
                "max": 1,
                "step": 0.05,
                "advanced": true,
                "label": "prefs.surfaces.shadow_blur",
                "description": "prefs.surfaces.shadow_blur.desc",
                "keywords": "shell shadow blur softness diffusion hard soft"
            },
            {
                "key": "theme.shadowXOffset",
                "type": "slider",
                "min": -20,
                "max": 20,
                "step": 1,
                "unit": "px",
                "advanced": true,
                "label": "prefs.surfaces.shadow_x",
                "description": "prefs.surfaces.shadow_x.desc",
                "keywords": "shell shadow offset horizontal x left right"
            },
            {
                "key": "theme.shadowYOffset",
                "type": "slider",
                "min": -20,
                "max": 20,
                "step": 1,
                "unit": "px",
                "advanced": true,
                "label": "prefs.surfaces.shadow_y",
                "description": "prefs.surfaces.shadow_y.desc",
                "keywords": "shell shadow offset vertical y up down"
            }
        ]
    }
];
