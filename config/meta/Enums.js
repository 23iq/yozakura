.pragma library
.import "../../modules/bar/BarLayout.js" as BarLayout
.import "../../modules/bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
.import "../../modules/bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles
.import "../../modules/components/surfaceeffects/SurfaceEffects.js" as SurfaceEffects
.import "../../modules/desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles
.import "../../modules/lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "../../modules/desktop/widgets/WidgetRegistry.js" as WidgetRegistry
.import "../../modules/services/voice/VoiceModel.js" as VoiceModel
.import "../../modules/widgets/launcher/Providers.js" as LauncherProviders
.import "../../modules/notifications/NotificationPolicy.js" as NotificationPolicy
.import "../../modules/theme/AppThemes.js" as AppThemes
.import "../../modules/specials/Specials.js" as Specials

// Allowed values of enumerated config keys. Shared by ConfigValidator.js
// (runtime clamping) and config/meta/*.js (the generated settings catalog in
// assets/schema, used by `yozakura config` and the MCP config tools). Lists
// owned by a registry are read from it, so adding a clock style / lock
// screen style / numeral
// system / bar module stays one file + one entry.

var EDGES = ["top", "bottom", "left", "right"];
var VERTICAL_EDGES = ["top", "bottom"];
var GRADIENT_TYPES = ["linear", "radial", "halftone"];
var WALLPAPER_TRANSITIONS = ["grow", "wipe", "dissolve", "fade", "random", "none"];
var BAR_STYLES = BarLayout.STYLES;
var BAR_MODULES = BarLayout.MODULE_IDS;
var PILL_STYLES = ["default", "squished"];
var NOTCH_THEMES = ["default", "island"];
var DOCK_THEMES = ["default", "floating", "integrated"];
var EXPAND_ON = ["hover", "click"];
var ACTIVITY_PRESENTATIONS = ["notch", "islands", "off"];
var NO_MEDIA_DISPLAY = ["userHost", "compositor", "custom"];
var COMPOSITOR_LAYOUTS = ["dwindle", "master", "scrolling"];
var AI_MODES = ["chat", "agent", "shell"];
var AI_SELECTION_OUTPUTS = ["replace", "clipboard", "sidebar"];
var SIDES = ["left", "right"];
var TEMPERATURE_UNITS = ["C", "F"];
var VOICE_ACTIVATIONS = VoiceModel.ACTIVATIONS;
var VOICE_TYPING_METHODS = VoiceModel.TYPING_METHODS;
var VOICE_MODELS = VoiceModel.MODELS;
var VOICE_LANGUAGES = VoiceModel.LANGUAGES;
var CLOCK_POSITIONS = ClockStyles.POSITIONS;
var NOTIFICATION_PRESENTATIONS = NotificationPolicy.PRESENTATIONS;
var NOTIFICATION_POSITIONS = NotificationPolicy.POSITIONS;
var NOTIFICATION_RULE_ACTIONS = NotificationPolicy.RULE_ACTIONS;
var THEMED_APPS = AppThemes.ids();
var LOCK_TONES = LockStyles.TONES;
var CLOCK_INKS = ClockStyles.INKS;
var WIDGET_TYPES = WidgetRegistry.ids();
var WIDGET_VARIANTS = WidgetRegistry.VARIANTS;

function clockStyles() {
    return ClockStyles.ids();
}

function lockStyles() {
    return LockStyles.ids();
}

function numeralStyles() {
    return WorkspaceNumerals.ids();
}

function indicatorStyles() {
    return IndicatorStyles.ids();
}

function surfaceEffects() {
    return SurfaceEffects.ids();
}

// Launcher result providers (modules/widgets/launcher/Providers.js) and the
// prefix tabs that can be turned off.
var LAUNCHER_PROVIDERS = LauncherProviders.INLINE_IDS;
var LAUNCHER_TABS = LauncherProviders.TAB_IDS;

// Special workspaces (modules/specials/Specials.js).
var SPECIAL_ACCENTS = Specials.ACCENTS;
var SPECIAL_IF_RUNNING = Specials.IF_RUNNING;
