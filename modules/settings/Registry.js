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
    "BarPositionPicker": "editors/BarPositionPicker.qml",
    "NumeralCards": "editors/NumeralCards.qml",
    "IndicatorStyleChips": "editors/IndicatorStyleChips.qml",
    "SurfaceEffectCards": "editors/SurfaceEffectCards.qml",
    "WallpaperGrid": "editors/WallpaperGrid.qml",
    "FolderList": "editors/FolderList.qml",
    "SpecialsEditor": "editors/SpecialsEditor.qml",
    "ComingSoonRow": "editors/ComingSoonRow.qml",
    "DepthClockLink": "editors/DepthClockLink.qml",
    "ClockStyleGallery": "editors/ClockStyleGallery.qml",
    "ColorRoleSwatches": "editors/ColorRoleSwatches.qml",
    "DesktopWidgetsEditor": "editors/DesktopWidgetsEditor.qml",
    "LegacyLink": "editors/LegacyLink.qml",
    "ActivitiesEditor": "editors/ActivitiesEditor.qml",
    "AiAgentsEditor": "editors/AiAgentsEditor.qml",
    "AiMcpEditor": "editors/AiMcpEditor.qml",
    "AiPromptsEditor": "editors/AiPromptsEditor.qml",
    "AiAutomationsEditor": "editors/AiAutomationsEditor.qml",
    "AiProvidersEditor": "editors/AiProvidersEditor.qml",
    "AiDefaultModel": "editors/AiDefaultModel.qml",
    "AiProviderVisibility": "editors/AiProviderVisibility.qml",
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
    "VoiceStatus": "editors/VoiceStatus.qml",
    "UpdatesStatus": "editors/UpdatesStatus.qml",
    "OcrLanguages": "editors/OcrLanguages.qml",
    "TerminalGlassLink": "editors/TerminalGlassLink.qml",
    "AppThemingEditor": "editors/AppThemingEditor.qml",
    "NotificationsStatus": "editors/NotificationsStatus.qml"
};

var PREVIEWS = {
    "RoundnessPreview": "previews/RoundnessPreview.qml",
    "MotionPreview": "previews/MotionPreview.qml",
    "PaletteFadePreview": "previews/PaletteFadePreview.qml",
    "ClockPreview": "previews/ClockPreview.qml",
    "TransitionPreview": "previews/TransitionPreview.qml",
    "GlassPreview": "previews/GlassPreview.qml",
    "DepthMatteStatus": "previews/DepthMatteStatus.qml",
    "WindowsPreview": "previews/WindowsPreview.qml"
};

function editor(name) {
    return EDITORS[name] || "";
}

function preview(name) {
    return PREVIEWS[name] || "";
}
