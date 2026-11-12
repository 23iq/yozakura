pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store

// Matugen scheme picker: one card per scheme, previewed with the palette
// that scheme produces for the current wallpaper (SchemePreviews), plus the
// color presets. Applies immediately (wallpapers.json).
Item {
    id: root

    property var entry
    readonly property var schemes: ["scheme-tonal-spot", "scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow"]
    readonly property string current: SettingsStore.get("wallpaper.matugenScheme") || ""
    readonly property string preset: SettingsStore.get("wallpaper.activeColorPreset") || ""
    readonly property string mode: Config.theme.lightMode ? "light" : "dark"
    readonly property var presets: GlobalStates.wallpaperManager ? (GlobalStates.wallpaperManager.colorPresets || []) : []
    readonly property int columns: Math.max(2, Math.min(4, Math.floor((width + Space.m) / 170)))
    readonly property real cardWidth: (width - grid.columnSpacing * (columns - 1)) / columns

    implicitHeight: column.implicitHeight

    Component.onCompleted: SchemePreviews.refresh()

    Column {
        id: column
        width: parent.width
        spacing: Space.l

        // Only what is worth a line: loading, unavailable, a preset in use.
        KitText {
            width: parent.width
            visible: text !== ""
            role: "caption"
            text: SchemePreviews.loading ? I18n.t("prefs.scheme.loading") : (SchemePreviews.failed ? I18n.t("prefs.scheme.unavailable") : (root.preset ? I18n.t("prefs.scheme.preset_active", root.preset) : ""))
            color: SchemePreviews.failed ? Colors.error : Type.muted
        }

        Grid {
            id: grid
            width: parent.width
            columns: root.columns
            rowSpacing: Space.l
            columnSpacing: Space.l

            Repeater {
                model: root.schemes

                delegate: ChoiceCard {
                    id: card
                    required property string modelData
                    readonly property var pal: SchemePreviews.palette(modelData, root.mode)
                    width: root.cardWidth
                    previewHeight: Space.controlL + Space.s
                    selected: !root.preset && root.current === modelData
                    title: I18n.t("wallpapers." + modelData.replace(/-/g, "_"))
                    onClicked: SettingsStore.set("wallpaper.matugenScheme", modelData)

                    SchemeSwatch {
                        anchors.fill: parent
                        colorMap: card.pal
                    }
                }
            }
        }

        // Color presets (fixed palettes, not derived from the wallpaper)
        Column {
            width: parent.width
            spacing: Space.s
            visible: root.presets.length > 0

            SectionLabel {
                width: parent.width
                text: I18n.t("prefs.scheme.presets")
            }
            Flow {
                width: parent.width
                spacing: Space.s
                Repeater {
                    model: root.presets
                    delegate: Chip {
                        required property string modelData
                        active: root.preset === modelData
                        text: modelData
                        onClicked: SettingsStore.set("wallpaper.activeColorPreset", active ? "" : modelData)
                    }
                }
            }
        }
    }
}
