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
    objectName: "themeModeCards"

    property var entry
    readonly property bool light: !!SettingsStore.get("theme.lightMode")
    readonly property bool oled: !light && !!SettingsStore.get("theme.oledMode")
    readonly property string mode: light ? "light" : (oled ? "oled" : "dark")
    readonly property string scheme: SettingsStore.get("wallpaper.matugenScheme") || "scheme-tonal-spot"
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures with the title inside, scrolling
    // sideways with an edge fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: 3
    readonly property real stripWidth: root.stripCount * Space.px(96) + Space.m * (root.stripCount + 1) <= root.width ? (root.width - Space.m * (root.stripCount + 1)) / Math.max(1, root.stripCount) : (root.width - Space.m * 2) / (Math.max(1, Math.floor((root.width - Space.m * 2) / Space.px(96))) + 0.4) - Space.m
    readonly property int columns: root.strip ? root.stripCount : width < 520 ? 1 : 3

    // beside the stage (a narrow place): a compact icon segmented
    readonly property bool compact: !root.strip && root.width > 0 && root.width < Space.px(300)
    readonly property var modes: [
        {
            "id": "dark",
            "icon": "moon",
            "title": "prefs.appearance.mode.dark"
        },
        {
            "id": "oled",
            "icon": "circleHalf",
            "title": "prefs.appearance.mode.oled"
        },
        {
            "id": "light",
            "icon": "sun",
            "title": "prefs.appearance.mode.light"
        }
    ]
    implicitHeight: root.strip ? root.fillHeight : (root.compact ? modeSegmented.height : grid.implicitHeight)

    // beside the stage: three stacked chips, each a swatch of the mode
    // (dark, black, light) and its name; the chosen one ringed
    Column {
        id: modeSegmented
        objectName: "themeModeChips"
        visible: root.compact
        width: parent.width
        spacing: Space.s
        Repeater {
            model: root.compact ? root.modes : []
            delegate: Card {
                id: chip
                required property var modelData
                readonly property bool chosen: modelData.id === root.mode
                objectName: "themeMode:" + modelData.id
                width: modeSegmented.width
                padding: Space.s
                interactive: true
                accented: chip.chosen
                onClicked: root.choose(chip.modelData.id)
                Row {
                    spacing: Space.m
                    Mark {
                        width: Space.controlS
                        height: width
                        radius: Look.radius("small", height)
                        color: chip.modelData.id === "light" ? Qt.rgba(0.96, 0.94, 0.94, 1) : (chip.modelData.id === "oled" ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(0.12, 0.09, 0.1, 1))
                        border.width: Space.hairline
                        border.color: Type.hairline
                        Mark {
                            anchors.centerIn: parent
                            width: parent.width * 0.4
                            height: width
                            color: Type.accent
                        }
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "body"
                        font.weight: chip.chosen ? Font.DemiBold : Font.Normal
                        text: I18n.t(chip.modelData.title)
                    }
                }
            }
        }
    }

    Component.onCompleted: SchemePreviews.refresh()

    // One undo step for the pair (Light -> OLED -> undo is Light again).
    function choose(id) {
        SettingsStore.transaction("prefs.appearance.mode", () => {
            SettingsStore.set("theme.lightMode", id === "light");
            // Light ignores OLED: the preference is kept for the way back.
            if (id !== "light")
                SettingsStore.set("theme.oledMode", id === "oled");
        });
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
            spacing: Space.l

            Repeater {
                model: root.compact ? [] : root.modes

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    width: root.strip ? root.stripWidth : (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                    previewHeight: root.strip ? root.fillHeight - Space.m * 2 : Math.round(width * 0.55)
                    inset: root.strip
                    selected: root.mode === modelData.id
                    icon: modelData.icon
                    title: I18n.t(modelData.title)
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
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
