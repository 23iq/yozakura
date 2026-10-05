.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/desktop.js (format: config/meta/Meta.js).

var description = "Desktop layer: icons, widgets, wallpaper folders and transition, and the depth clock drawn behind the wallpaper subject.";

var keys = {
    "enabled": {
        "description": "Show desktop icons."
    },
    "iconSize": {
        "min": 16,
        "max": 128,
        "unit": "px",
        "description": "Desktop icon size."
    },
    "spacingVertical": {
        "min": 0,
        "max": 64,
        "unit": "px",
        "description": "Vertical spacing between desktop icons."
    },
    "textColor": {
        "format": "color",
        "description": "Desktop icon label color (color spec)."
    },
    "blurWallpaperOnOverview": {
        "description": "Blur the wallpaper while the workspace overview is open."
    },
    "wallpaperTransition": {
        "enum": Enums.WALLPAPER_TRANSITIONS,
        "description": "Animation used when the wallpaper changes."
    },
    "wallpaperTransitionDuration": {
        "min": 0,
        "max": 5000,
        "unit": "ms",
        "description": "Wallpaper transition duration."
    },
    "wallpaperFolders": {
        "local": true,
        "items": {
            "type": "string"
        },
        "description": "Extra folders scanned for wallpapers."
    },
    "depthClock": {
        "description": "Depth clock: a big clock placed between the wallpaper background and its subject."
    },
    "depthClockStyle": {
        "enum": Enums.clockStyles(),
        "description": "Depth clock style (registry: modules/desktop/clockstyles/ClockStyleRegistry.js)."
    },
    "depthClockPosition": {
        "enum": Enums.CLOCK_POSITIONS,
        "description": "Side of the screen for the depth clock (auto picks the emptier side)."
    },
    "depthClockVideo": {
        "description": "Also show the depth clock on video wallpapers."
    },
    "depthClockInk": {
        "enum": Enums.CLOCK_INKS,
        "description": "Depth clock colour: auto (light or dark ink picked from the backdrop) or a palette role."
    },
    "widgetsEnabled": {
        "description": "Show the desktop widgets."
    },
    "widgets": {
        "items": {
            "type": "object",
            "required": ["type", "x", "y", "w", "h"],
            "properties": {
                "id": {
                    "type": "string"
                },
                "type": {
                    "enum": Enums.WIDGET_TYPES
                },
                "monitor": {
                    "type": "string"
                },
                "x": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1
                },
                "y": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1
                },
                "w": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1
                },
                "h": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1
                },
                "options": {
                    "type": "object"
                }
            }
        },
        "description": "Desktop widgets: [{id, type, monitor, x, y, w, h, options}]. type: media | calendar | system | note | weather (registry: modules/desktop/widgets/WidgetRegistry.js). x/y/w/h are fractions of the screen (0..1) so layouts survive resolution changes; monitor is the output name (empty or unknown = first screen); options are per type (see the registry)."
    },
    "widgetGrid": {
        "min": 0,
        "max": 128,
        "unit": "px",
        "description": "Snap grid for moving and resizing desktop widgets (0 = free placement)."
    },
    "widgetVariant": {
        "enum": Enums.WIDGET_VARIANTS,
        "description": "Surface style of desktop widgets (StyledRect variant; glass applies through theme.glass.surfaces.widgets)."
    }
};
