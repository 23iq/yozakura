.pragma library

// Rich editors (schema `type: "custom"`, `component`) and previews (schema
// `preview`) by name. Loaded by URL from SettingRow.qml; listing them here
// keeps them discoverable (audit dead-code, tests) and lets the schema
// audit reject unknown names.

var EDITORS = {
    "ThemeModeCards": "editors/ThemeModeCards.qml",
    "SchemeGallery": "editors/SchemeGallery.qml",
    "BarStyleCards": "editors/BarStyleCards.qml",
    "BarLayoutEditor": "editors/BarLayoutEditor.qml",
    "PanelsEditor": "editors/PanelsEditor.qml",
    "PanelList": "editors/PanelList.qml",
    "PanelShapeCards": "editors/PanelShapeCards.qml",
    "PanelModulesCard": "editors/PanelModulesCard.qml",
    "BarSizeCards": "editors/BarSizeCards.qml",
    "DockLookEditor": "editors/DockLookEditor.qml",
    "NumeralCards": "editors/NumeralCards.qml",
    "IndicatorCards": "editors/IndicatorCards.qml",
    "BranchBlossomChips": "editors/BranchBlossomChips.qml",
    "SurfaceEffectCards": "editors/SurfaceEffectCards.qml",
    "WallpaperStrip": "editors/WallpaperStrip.qml",
    "WallpaperColours": "editors/WallpaperColours.qml",
    "WallpaperScreens": "editors/WallpaperScreens.qml",
    "FolderList": "editors/FolderList.qml",
    "SpecialsEditor": "editors/SpecialsEditor.qml",
    "ComingSoonRow": "editors/ComingSoonRow.qml",
    "ClockStyleGallery": "editors/ClockStyleGallery.qml",
    "ColorRoleSwatches": "editors/ColorRoleSwatches.qml",
    "DesktopWidgetsMore": "editors/DesktopWidgetsMore.qml",
    "ActivitiesEditor": "editors/ActivitiesEditor.qml",
    "DashboardTabsList": "editors/DashboardTabsList.qml",
    "DesktopWidgetChips": "editors/DesktopWidgetChips.qml",
    "OrderedListEditor": "editors/OrderedListEditor.qml",
    "IslandActivitiesEditor": "editors/IslandActivitiesEditor.qml",
    "AiAgentsEditor": "editors/AiAgentsEditor.qml",
    "AiMcpEditor": "editors/AiMcpEditor.qml",
    "AiUsageData": "editors/AiUsageData.qml",
    "AiPromptsEditor": "editors/AiPromptsEditor.qml",
    "AiAutomationsEditor": "editors/AiAutomationsEditor.qml",
    "AiProvidersEditor": "editors/AiProvidersEditor.qml",
    "AiDefaultModel": "editors/AiDefaultModel.qml",
    "AiProviderVisibility": "editors/AiProviderVisibility.qml",
    "RoutinesEditor": "editors/RoutinesEditor.qml",
    "GlassAmountEditor": "editors/GlassAmountEditor.qml",
    "GlassSurfacesEditor": "editors/GlassSurfacesEditor.qml",
    "KeybindsOverview": "editors/KeybindsOverview.qml",
    "LockStyleGallery": "editors/LockStyleGallery.qml",
    "LoginScreenCard": "editors/LoginScreenCard.qml",
    "LauncherSearchChips": "editors/LauncherSearchChips.qml",
    "LauncherPrefixList": "editors/LauncherPrefixList.qml",
    "MotionProfileCards": "editors/MotionProfileCards.qml",
    "PageLink": "editors/PageLink.qml",
    "LanguageCards": "editors/LanguageCards.qml",
    "ExclusiveCard": "system/ExclusiveCard.qml",
    "VoiceStatus": "editors/VoiceStatus.qml",
    "OcrLanguages": "editors/OcrLanguages.qml",
    "TerminalGlassLink": "editors/TerminalGlassLink.qml",
    "TerminalLookEditor": "editors/TerminalLookEditor.qml",
    "PromptStrip": "editors/PromptStrip.qml",
    "GreetingChips": "editors/GreetingChips.qml",
    "FastfetchEditor": "editors/FastfetchEditor.qml",
    "CursorShapeChips": "editors/CursorShapeChips.qml",
    "AppThemingEditor": "editors/AppThemingEditor.qml",
    "NotificationsStatus": "editors/NotificationsStatus.qml",
    "LayoutBuilder": "layout/LayoutBuilder.qml",
    "SurfaceRolesEditor": "editors/SurfaceRolesEditor.qml",
    "PomodoroEditor": "editors/PomodoroEditor.qml",
    "AiStripChips": "editors/AiStripChips.qml",
    "WindowBorderEditor": "editors/WindowBorderEditor.qml",
    "WindowCornersEditor": "editors/WindowCornersEditor.qml",
    "WindowGapsEditor": "editors/WindowGapsEditor.qml",
    "IdleTimeline": "editors/IdleTimeline.qml",
    "WifiList": "connect/WifiList.qml",
    "WifiDetails": "connect/WifiDetails.qml",
    "BluetoothList": "connect/BluetoothList.qml",
    "BluetoothDetails": "connect/BluetoothDetails.qml",
    "AudioDevices": "connect/AudioDevices.qml",
    "AppVolumes": "connect/AppVolumes.qml",
    "EffectPresets": "connect/EffectPresets.qml",
    "ShortcutList": "editors/ShortcutList.qml",
    "SleepSwitches": "editors/SleepSwitches.qml"
};

var PREVIEWS = {
    "RoundnessPreview": "previews/RoundnessPreview.qml",
    "MotionPreview": "previews/MotionPreview.qml",
    "PaletteFadePreview": "previews/PaletteFadePreview.qml",
    "LightingPreview": "previews/LightingPreview.qml",
    "WeatherFxPreview": "previews/WeatherFxPreview.qml",
    "SentencePreview": "previews/SentencePreview.qml",
    "GlassPreview": "previews/GlassPreview.qml",
    "DepthMatteStatus": "previews/DepthMatteStatus.qml",
    "StripsPreview": "previews/StripsPreview.qml",
    "LayoutPreview": "layout/LayoutPreview.qml"
};

// Card thumbnails of a selector shown as cards (schema `display: "cards"`,
// `thumb`): one small picture per option (`value`), see controls/CardSelector.
var THUMBS = {
    "LanguageThumb": "thumbs/LanguageThumb.qml",
    "CornerThumb": "thumbs/CornerThumb.qml",
    "EdgeThumb": "thumbs/EdgeThumb.qml",
    "DockStyleThumb": "thumbs/DockStyleThumb.qml",
    "IslandShapeThumb": "thumbs/IslandShapeThumb.qml",
    "OsdStyleThumb": "thumbs/OsdStyleThumb.qml",
    "PopupAnimThumb": "thumbs/PopupAnimThumb.qml",
    "PresentationThumb": "thumbs/PresentationThumb.qml",
    "BarEdgeThumb": "thumbs/BarEdgeThumb.qml",
    "ClockFaceThumb": "thumbs/ClockFaceThumb.qml",
    "ClockPanelThumb": "thumbs/ClockPanelThumb.qml",
    "IndicatorThumb": "thumbs/IndicatorThumb.qml",
    "NumeralThumb": "thumbs/NumeralThumb.qml",
    "WeightThumb": "thumbs/WeightThumb.qml",
    "WallFitThumb": "thumbs/WallFitThumb.qml",
    "WallTransitionThumb": "thumbs/WallTransitionThumb.qml",
    "LauncherStyleThumb": "thumbs/LauncherStyleThumb.qml",
    "DashHomeThumb": "thumbs/DashHomeThumb.qml",
    "OverviewStyleThumb": "thumbs/OverviewStyleThumb.qml",
    "ActivationThumb": "thumbs/ActivationThumb.qml",
    "AiSizeThumb": "thumbs/AiSizeThumb.qml",
    "AiMessageThumb": "thumbs/AiMessageThumb.qml",
    "LocaleThumb": "thumbs/LocaleThumb.qml",
    "TilingThumb": "thumbs/TilingThumb.qml"
};

// The live miniature at the top of a schema page (category `stage`): a
// stages/<Name>.qml whose root is a Stage (see stages/Stage.qml).
// Tabs about something on the desktop: the only ones whose stage is a
// desktop miniature over the wallpaper (tests/settings-pages.test.cjs keeps
// it so). Every other tab has no stage, or (a list page) a plain status
// band with no picture.
var DESKTOP_STAGES = {
    "bar": "BarStage",
    "notch": "IslandStage",
    "dock": "DockStage",
    "desktop": "DesktopStage",
    "lockscreen": "LockStage",
    "notifications": "NotifStage",
    "menus": "OsdStage",
    "windows": "WindowsStage",
    "wallpapers": "WallpaperStage"
};
// Plain status bands of list pages (no picture behind them).
var BANDS = ["NetworkBand", "BluetoothBand", "SoundBand", "EffectsBand", "KeysBand", "ProvidersBand", "RoutinesBand"];

var STAGES = {
    "BarStage": "stages/BarStage.qml",
    "IslandStage": "stages/IslandStage.qml",
    "DockStage": "stages/DockStage.qml",
    "NotifStage": "stages/NotifStage.qml",
    "OsdStage": "stages/OsdStage.qml",
    "LockStage": "stages/LockStage.qml",
    "WallpaperStage": "stages/WallpaperStage.qml",
    "DesktopStage": "stages/DesktopStage.qml",
    "RoutinesBand": "stages/RoutinesBand.qml",
    "ProvidersBand": "stages/ProvidersBand.qml",
    "WindowsStage": "stages/WindowsStage.qml",
    "NetworkBand": "stages/NetworkBand.qml",
    "BluetoothBand": "stages/BluetoothBand.qml",
    "SoundBand": "stages/SoundBand.qml",
    "EffectsBand": "stages/EffectsBand.qml",
    "KeysBand": "stages/KeysBand.qml"
};

// Hand-written pages (category `page`), loaded by URL by SettingsPageHost
// so none of them is compiled before it is opened. `props`: extra
// properties set on creation (besides `category`).
var PAGES = {
    "AboutPage": { "file": "AboutPage.qml" },
    "Changes": { "file": "changes/ChangesPage.qml" },
    "Displays": { "file": "displays/DisplaysPage.qml" },
    "Extras": { "file": "extras/ExtrasPage.qml" },
    "Keyboard": { "file": "keyboard/KeyboardPage.qml" },
    "Mods": { "file": "mods/ModsEditor.qml" },
    "PresetStudio": { "file": "presets/PresetStudioPage.qml" }
};

// Home tile scenes (HomeTile, loaded by URL once home has shown), by
// destination id.
var SCENES = {
    "look": "home/LookScene.qml",
    "screen": "home/LayoutScene.qml",
    "windows": "home/WindowsScene.qml",
    "panels": "home/LauncherScene.qml",
    "notifications": "home/NotifScene.qml",
    "assistant": "home/AssistantScene.qml",
    "keys": "home/KeysScene.qml",
    "devices": "home/DisplaysScene.qml",
    "system": "home/SystemScene.qml"
};

function scene(id) {
    return SCENES[id] || "";
}

function stage(name) {
    return STAGES[name] || "";
}

function page(name) {
    return PAGES[name] || null;
}

function editor(name) {
    return EDITORS[name] || "";
}

function preview(name) {
    return PREVIEWS[name] || "";
}

function thumb(name) {
    return THUMBS[name] || "";
}
