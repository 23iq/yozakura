.pragma library

// QML property types of config keys that their default value does not tell
// (tools/config/gen_adapters.cjs builds config/adapters/<Domain>Adapter.qml
// from config/defaults/<domain>.js). Without an entry the type is inferred:
//   boolean -> bool, string -> string, number -> real,
//   non-empty array of strings -> list<string>, other array -> list<var>,
//   object -> JsonObject (its keys are typed config keys, recursively).
// Entries (dotted path inside the domain):
//   "int"           whole numbers; a fractional value is truncated on load
//   "var"           free-form JSON (an object whose keys are not config keys)
//   "list<string>"  e.g. an array that defaults to []
//   "list<var>"
// Run `make schema` after changing this file or config/defaults.

var types = {
    "theme": {
        "animDuration": "int",
        "fontSize": "int",
        "monoFontSize": "int",
        "paletteTransitionDuration": "int",
        "roundness": "int",
        "shadowXOffset": "int",
        "shadowYOffset": "int",
        "srBarBg.gradientAngle": "int",
        "srBg.gradientAngle": "int",
        "srCommon.gradientAngle": "int",
        "srError.gradientAngle": "int",
        "srErrorFocus.gradientAngle": "int",
        "srFocus.gradientAngle": "int",
        "srFrame.gradientAngle": "int",
        "srInternalBg.gradientAngle": "int",
        "srOverError.gradientAngle": "int",
        "srOverPrimary.gradientAngle": "int",
        "srOverSecondary.gradientAngle": "int",
        "srOverTertiary.gradientAngle": "int",
        "srPane.gradientAngle": "int",
        "srPopup.gradientAngle": "int",
        "srPrimary.gradientAngle": "int",
        "srPrimaryFocus.gradientAngle": "int",
        "srSecondary.gradientAngle": "int",
        "srSecondaryFocus.gradientAngle": "int",
        "srTertiary.gradientAngle": "int",
        "srTertiaryFocus.gradientAngle": "int"
    },
    "bar": {
        "activities": "var",
        "frameThickness": "int",
        "hoverRegionHeight": "int",
        "launcherIconSize": "int",
        "layout": "var",
        "moduleOptions": "var",
        "panels": "var",
        "screenList": "list<string>"
    },
    "specials": {
        "launchTimeout": "int",
        "preloadDelay": "int"
    },
    "workspaces": {
        "shown": "int",
        "specialWorkspaceAnimationDuration": "int"
    },
    "overview": {
        "columns": "int",
        "rows": "int"
    },
    "notch": {
        "expandedArtworkSize": "int",
        "expandedMediaWidth": "int",
        "hoverCollapseDelay": "int",
        "hoverExpandDelay": "int",
        "hoverRegionHeight": "int",
        "mediaAnimationDuration": "int",
        "microphoneNoticeDuration": "int"
    },
    "compositor": {
        "activeBorderColor": "var",
        "blurPasses": "int",
        "blurSize": "int",
        "borderAngle": "int",
        "borderSize": "int",
        "gapsIn": "int",
        "gapsOut": "int",
        "inactiveBorderAngle": "int",
        "inactiveBorderColor": "var",
        "motionBorderLoopSpeed": "int",
        "motionOverrides": "var",
        "rounding": "int",
        "shadowRange": "int",
        "shadowRenderPower": "int"
    },
    "performance": {
        "dashboardMaxPersistentTabs": "int"
    },
    "voice": {
        "idleTimeout": "int",
        "maxSeconds": "int",
        "noSpeechTimeout": "int",
        "previewMs": "int",
        "vadSilenceMs": "int"
    },
    "notifications": {
        "historySize": "int",
        "maxVisible": "int",
        "screens": "list<string>",
        "timeout": "int"
    },
    "apps": {
        "kitty.fontSize": "int"
    },
    "desktop": {
        "iconSize": "int",
        "spacingVertical": "int",
        "wallpaperFolders": "list<string>",
        "wallpaperTransitionDuration": "int",
        "widgetGrid": "int"
    },
    "prefix": {
        "launcher.currencyRefreshHours": "int",
        "launcher.disabled": "list<string>",
        "launcher.fileMaxResults": "int"
    },
    "system": {
        "focus.minutes": "int",
        "pomodoro.restTime": "int",
        "pomodoro.workTime": "int",
        "timers.alarmInterval": "int",
        "timers.alarmRepeat": "int",
        "timers.reminderLead": "int"
    },
    "dock": {
        "height": "int",
        "hoverRegionHeight": "int",
        "iconSize": "int",
        "margin": "int",
        "screenList": "list<string>",
        "spacing": "int"
    },
    "ai": {
        "agents.autoApprove": "list<var>",
        "context.autoCompactAt": "int",
        "context.criticalAt": "int",
        "context.keepTurns": "int",
        "context.overrides": "list<var>",
        "context.warnAt": "int",
        "maxToolRounds": "int",
        "tasks.doneLimit": "int",
        "tasks.maxParallel": "int",
        "ollama.numCtx": "int",
        "providers.customHeaders": "list<var>",
        "providers.hidden": "list<string>",
        "providers.probeInterval": "int",
        "providers.retries": "int",
        "providers.timeout": "int",
        "quickAsk.width": "int",
        "sidebarWidth": "int",
        "unloadAfterMinutes": "int",
        "usage.criticalAt": "int",
        "usage.decimals": "int",
        "usage.hiddenProviders": "list<string>",
        "usage.warnAt": "int",
        "wideWidth": "int"
    }
};
