pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.components.kit
import qs.modules.settings.controls
import "../controls/PictureGrid.js" as PictureGrid
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
    // a strip of swatch cards in a card of the page row (its height)
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int columns: root.strip ? Math.max(1, root.schemes.length) : PictureGrid.columns(width, grid.columnSpacing, root.schemes.length, Space.px(124))
    readonly property real cardWidth: root.strip ? Math.max(Space.px(96), (root.fillHeight - Space.xl) * 1.3) : PictureGrid.cardWidth(width, grid.columnSpacing, columns, Space.px(190))

    implicitHeight: root.strip ? root.fillHeight : column.implicitHeight

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

        Flickable {
            id: stripFlick
            objectName: "pictureStrip"
            width: parent.width
            height: grid.height + (root.strip ? Space.m * 2 : 0)
            contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
            interactive: root.strip && contentWidth > width
            clip: root.strip
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Grid {
                id: grid
                width: root.strip ? implicitWidth : stripFlick.width
                // inset: the ring, glow and lift of a picture never clip
                x: root.strip ? Space.m : 0
                y: root.strip ? Space.m : 0
                columns: root.columns
                rowSpacing: Space.l
                columnSpacing: Space.m

                Repeater {
                    model: root.schemes

                    delegate: ChoiceCard {
                        id: card
                        required property string modelData
                        readonly property var pal: SchemePreviews.palette(modelData, root.mode)
                        width: root.cardWidth
                        previewHeight: root.strip ? Math.max(Space.controlM, root.fillHeight - Space.xl - Space.m * 2) : Space.controlL + Space.s
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
        }

        // Color presets (fixed palettes, not derived from the wallpaper)
        Column {
            width: parent.width
            spacing: Space.s
            visible: root.presets.length > 0 && !root.strip

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
