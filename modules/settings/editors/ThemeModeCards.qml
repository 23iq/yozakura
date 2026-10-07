pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import qs.modules.components.kit

// Dark / OLED / Light, each previewed with the palette the current
// wallpaper + scheme produce in that mode (SchemePreviews).
Item {
    id: root

    property var entry
    readonly property bool light: !!SettingsStore.get("theme.lightMode")
    readonly property bool oled: !light && !!SettingsStore.get("theme.oledMode")
    readonly property string mode: light ? "light" : (oled ? "oled" : "dark")
    readonly property string scheme: SettingsStore.get("wallpaper.matugenScheme") || "scheme-tonal-spot"
    readonly property int columns: width < 520 ? 1 : 3

    implicitHeight: grid.implicitHeight

    Component.onCompleted: SchemePreviews.refresh()

    function choose(id) {
        SettingsStore.set("theme.lightMode", id === "light");
        SettingsStore.set("theme.oledMode", id === "oled");
    }

    // Palette for a mode; null = the live Colors (already that mode).
    function paletteFor(id) {
        const m = id === "light" ? "light" : "dark";
        const p = SchemePreviews.palette(scheme, m);
        if (p)
            return p;
        if ((m === "light") === light)
            return null;
        // Unknown other-mode palette: a role swap of the live one.
        return {
            "background": Colors.overBackground,
            "surfaceContainer": Colors.overSurfaceVariant,
            "surfaceContainerHigh": Colors.overSurface,
            "overBackground": Colors.background,
            "overSurfaceVariant": Colors.surfaceVariant,
            "outlineVariant": Colors.outline,
            "primary": Colors.primaryContainer,
            "secondaryContainer": Colors.secondary,
            "secondary": Colors.secondaryContainer,
            "tertiary": Colors.tertiaryContainer
        };
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Space.m

        Repeater {
            model: [
                {
                    "id": "dark",
                    "icon": "moon",
                    "title": "prefs.appearance.mode.dark",
                    "subtitle": "prefs.appearance.mode.dark.desc"
                },
                {
                    "id": "oled",
                    "icon": "circleHalf",
                    "title": "prefs.appearance.mode.oled",
                    "subtitle": "prefs.appearance.mode.oled.desc"
                },
                {
                    "id": "light",
                    "icon": "sun",
                    "title": "prefs.appearance.mode.light",
                    "subtitle": "prefs.appearance.mode.light.desc"
                }
            ]

            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * 0.55)
                selected: root.mode === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.title)
                subtitle: I18n.t(modelData.subtitle)
                onClicked: root.choose(modelData.id)

                MiniDesktop {
                    anchors.fill: parent
                    colorMap: root.paletteFor(card.modelData.id)
                    oled: card.modelData.id === "oled"
                }
            }
        }
    }
}
