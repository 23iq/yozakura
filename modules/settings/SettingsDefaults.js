.pragma library
.import "../../config/defaults/theme.js" as ThemeDefaults
.import "../../config/defaults/bar.js" as BarDefaults
.import "../../config/defaults/workspaces.js" as WorkspacesDefaults
.import "../../config/defaults/desktop.js" as DesktopDefaults
.import "../../config/defaults/notch.js" as NotchDefaults
.import "../../config/defaults/dock.js" as DockDefaults
.import "../../config/defaults/lockscreen.js" as LockscreenDefaults
.import "../../config/defaults/overview.js" as OverviewDefaults
.import "../../config/defaults/compositor.js" as CompositorDefaults
.import "../../config/defaults/system.js" as SystemDefaults
.import "../../config/defaults/general.js" as GeneralDefaults
.import "../../config/defaults/voice.js" as VoiceDefaults
.import "../../config/defaults/ai.js" as AiDefaults
.import "../../config/defaults/performance.js" as PerformanceDefaults
.import "../../config/defaults/prefix.js" as PrefixDefaults
.import "../../config/defaults/weather.js" as WeatherDefaults
.import "../../config/defaults/notifications.js" as NotificationsDefaults
.import "../../config/defaults/apps.js" as AppsDefaults
.import "../../config/defaults/specials.js" as SpecialsDefaults
.import "../../config/defaults/terminal.js" as TerminalDefaults
.import "SchemaUtil.js" as SchemaUtil

// Default value of any settings key, read from config/defaults/*.js (the
// same blueprint Config.qml validates against). Wallpaper keys live in
// ~/.cache/yozakura/wallpapers.json; their defaults mirror Wallpaper.qml.

var DOMAINS = {
    "theme": ThemeDefaults.data,
    "bar": BarDefaults.data,
    "workspaces": WorkspacesDefaults.data,
    "desktop": DesktopDefaults.data,
    "notch": NotchDefaults.data,
    "dock": DockDefaults.data,
    "lockscreen": LockscreenDefaults.data,
    "overview": OverviewDefaults.data,
    "compositor": CompositorDefaults.data,
    "system": SystemDefaults.data,
    "general": GeneralDefaults.data,
    "voice": VoiceDefaults.data,
    "ai": AiDefaults.data,
    "performance": PerformanceDefaults.data,
    "prefix": PrefixDefaults.data,
    "weather": WeatherDefaults.data,
    "notifications": NotificationsDefaults.data,
    "apps": AppsDefaults.data,
    "specials": SpecialsDefaults.data,
    "terminal": TerminalDefaults.data,
    "wallpaper": {
        "matugenScheme": "scheme-tonal-spot",
        "activeColorPreset": "",
        "wallPath": ""
    }
};

function get(key) {
    var k = SchemaUtil.splitKey(key);
    var domain = DOMAINS[k.domain];
    if (!domain)
        return undefined;
    var v = SchemaUtil.getPath(domain, k.path);
    return v === undefined ? undefined : SchemaUtil.plain(v);
}
