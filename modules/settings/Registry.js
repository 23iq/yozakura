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
    "NumeralCards": "editors/NumeralCards.qml",
    "IndicatorCards": "editors/IndicatorCards.qml",
    "BranchBlossomChips": "editors/BranchBlossomChips.qml",
    "SurfaceEffectCards": "editors/SurfaceEffectCards.qml",
    "WallpaperGrid": "editors/WallpaperGrid.qml",
    "FolderList": "editors/FolderList.qml",
    "SpecialsEditor": "editors/SpecialsEditor.qml",
    "ComingSoonRow": "editors/ComingSoonRow.qml",
    "ClockStyleGallery": "editors/ClockStyleGallery.qml",
    "ColorRoleSwatches": "editors/ColorRoleSwatches.qml",
    "DesktopWidgetsEditor": "editors/DesktopWidgetsEditor.qml",
    "ActivitiesEditor": "editors/ActivitiesEditor.qml",
    "DashboardTabsEditor": "editors/DashboardTabsEditor.qml",
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
    "KeybindGroupEditor": "editors/KeybindGroupEditor.qml",
    "LockStyleGallery": "editors/LockStyleGallery.qml",
    "LoginScreenCard": "editors/LoginScreenCard.qml",
    "LauncherProvidersEditor": "editors/LauncherProvidersEditor.qml",
    "MotionProfileCards": "editors/MotionProfileCards.qml",
    "PageLink": "editors/PageLink.qml",
    "LanguagePicker": "editors/LanguagePicker.qml",
    "ExclusiveCard": "system/ExclusiveCard.qml",
    "VoiceStatus": "editors/VoiceStatus.qml",
    "UpdatesStatus": "editors/UpdatesStatus.qml",
    "OcrLanguages": "editors/OcrLanguages.qml",
    "TerminalGlassLink": "editors/TerminalGlassLink.qml",
    "TerminalLookEditor": "editors/TerminalLookEditor.qml",
    "FastfetchEditor": "editors/FastfetchEditor.qml",
    "CursorShapeChips": "editors/CursorShapeChips.qml",
    "AppThemingEditor": "editors/AppThemingEditor.qml",
    "NotificationsStatus": "editors/NotificationsStatus.qml",
    "LayoutBuilder": "layout/LayoutBuilder.qml",
    "SurfaceRolesEditor": "editors/SurfaceRolesEditor.qml",
    "WindowBorderEditor": "editors/WindowBorderEditor.qml",
    "WindowCornersEditor": "editors/WindowCornersEditor.qml",
    "WindowGapsEditor": "editors/WindowGapsEditor.qml"
};

var PREVIEWS = {
    "RoundnessPreview": "previews/RoundnessPreview.qml",
    "MotionPreview": "previews/MotionPreview.qml",
    "PaletteFadePreview": "previews/PaletteFadePreview.qml",
    "LightingPreview": "previews/LightingPreview.qml",
    "WeatherFxPreview": "previews/WeatherFxPreview.qml",
    "SentencePreview": "previews/SentencePreview.qml",
    "TransitionPreview": "previews/TransitionPreview.qml",
    "PanoramaPreview": "previews/PanoramaPreview.qml",
    "GlassPreview": "previews/GlassPreview.qml",
    "DepthMatteStatus": "previews/DepthMatteStatus.qml",
    "OsdPreview": "previews/OsdPreview.qml",
    "StripsPreview": "previews/StripsPreview.qml",
    "LayoutPreview": "layout/LayoutPreview.qml"
};

// Card thumbnails of a selector shown as cards (schema `display: "cards"`,
// `thumb`): one small picture per option (`value`), see controls/CardSelector.
var THUMBS = {
    "LanguageThumb": "thumbs/LanguageThumb.qml",
    "CornerThumb": "thumbs/CornerThumb.qml",
    "EdgeThumb": "thumbs/EdgeThumb.qml",
    "PresentationThumb": "thumbs/PresentationThumb.qml",
    "BarEdgeThumb": "thumbs/BarEdgeThumb.qml",
    "ClockFaceThumb": "thumbs/ClockFaceThumb.qml",
    "ClockPanelThumb": "thumbs/ClockPanelThumb.qml",
    "IndicatorThumb": "thumbs/IndicatorThumb.qml",
    "NumeralThumb": "thumbs/NumeralThumb.qml",
    "WeightThumb": "thumbs/WeightThumb.qml",
    "TilingThumb": "thumbs/TilingThumb.qml"
};

// The live miniature at the top of a schema page (category `stage`): a
// stages/<Name>.qml whose root is a Stage (see stages/Stage.qml).
var STAGES = {
    "BarStage": "stages/BarStage.qml",
    "IslandStage": "stages/IslandStage.qml",
    "DockStage": "stages/DockStage.qml",
    "OpensStage": "stages/OpensStage.qml",
    "LookStage": "stages/LookStage.qml",
    "TypeStage": "stages/TypeStage.qml",
    "NotifStage": "stages/NotifStage.qml",
    "LockStage": "stages/LockStage.qml",
    "WindowsStage": "stages/WindowsStage.qml"
};

// Hand-written pages (category `page`), loaded by URL by SettingsPageHost
// so none of them is compiled before it is opened. `props`: extra
// properties set on creation (besides `category`).
var PAGES = {
    "AboutPage": { "file": "AboutPage.qml" },
    "Bluetooth": { "file": "connect/ConnectPage.qml", "props": { "panel": "BluetoothPanel.qml" } },
    "Changes": { "file": "changes/ChangesPage.qml" },
    "Displays": { "file": "displays/DisplaysPage.qml" },
    "Effects": { "file": "connect/ConnectPage.qml", "props": { "panel": "EasyEffectsPanel.qml" } },
    "Extras": { "file": "extras/ExtrasPage.qml" },
    "Keyboard": { "file": "keyboard/KeyboardPage.qml" },
    "Mods": { "file": "mods/ModsEditor.qml" },
    "Network": { "file": "connect/ConnectPage.qml", "props": { "panel": "WifiPanel.qml" } },
    "PresetStudio": { "file": "presets/PresetStudioPage.qml" },
    "Sound": { "file": "connect/ConnectPage.qml", "props": { "panel": "AudioMixerPanel.qml" } }
};

// Home tile scenes (HomeTile, loaded by URL once home has shown), by
// destination id.
var SCENES = {
    "layout": "home/LayoutScene.qml",
    "wallpaper": "home/WallpaperScene.qml",
    "lockscreen": "home/LockScene.qml",
    "look": "home/LookScene.qml",
    "notifications": "home/NotifScene.qml",
    "presets": "home/PresetsScene.qml",
    "launcher": "home/LauncherScene.qml",
    "dashboard": "home/DashboardScene.qml",
    "assistant": "home/AssistantScene.qml",
    "keys": "home/KeysScene.qml",
    "displays": "home/DisplaysScene.qml",
    "windows": "home/WindowsScene.qml"
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
