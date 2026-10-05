pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../Ui.js" as Ui

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
    readonly property int columns: Math.max(2, Math.min(4, Math.floor((width + 12) / 170)))
    readonly property real cardWidth: (width - grid.spacing * (columns - 1)) / columns

    implicitHeight: column.implicitHeight

    Component.onCompleted: SchemePreviews.refresh()

    Column {
        id: column
        width: parent.width
        spacing: 16

        // Source wallpaper + status
        Row {
            spacing: 12
            width: parent.width

            Rectangle {
                width: 52
                height: 34
                radius: 8
                color: Colors.surfaceContainerHigh
                clip: true
                Image {
                    anchors.fill: parent
                    source: SchemePreviews.source ? "file://" + SchemePreviews.source : ""
                    sourceSize: Qt.size(104, 68)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64
                Text {
                    width: parent.width
                    text: I18n.t("prefs.scheme.from_wallpaper")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: SchemePreviews.loading ? I18n.t("prefs.scheme.loading") : (SchemePreviews.failed ? I18n.t("prefs.scheme.unavailable") : (root.preset ? I18n.t("prefs.scheme.preset_active", root.preset) : I18n.t("prefs.scheme.hint")))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: SchemePreviews.failed ? Colors.error : Colors.overSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: root.columns
            spacing: 12

            Repeater {
                model: root.schemes

                delegate: ChoiceCard {
                    id: card
                    required property string modelData
                    readonly property var pal: SchemePreviews.palette(modelData, root.mode)
                    width: root.cardWidth
                    previewHeight: 74
                    selected: !root.preset && root.current === modelData
                    title: I18n.t("wallpapers." + modelData.replace(/-/g, "_"))
                    subtitle: I18n.t("prefs.scheme." + modelData.replace("scheme-", "").replace(/-/g, "_"))
                    onClicked: SettingsStore.set("wallpaper.matugenScheme", modelData)

                    SwatchStrip {
                        anchors.fill: parent
                        colorMap: card.pal
                    }
                }
            }
        }

        // Color presets (fixed palettes, not derived from the wallpaper)
        Column {
            width: parent.width
            spacing: 8
            visible: root.presets.length > 0

            Text {
                text: I18n.t("prefs.scheme.presets")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurfaceVariant
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.presets
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool active: root.preset === modelData
                        width: chipText.implicitWidth + 28
                        height: 32
                        radius: height / 2
                        color: active ? Colors.primary : (chipArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : Ui.alpha(Colors.overBackground, 0.06))
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: chip.active ? Colors.overPrimary : Colors.overBackground
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsStore.set("wallpaper.activeColorPreset", chip.active ? "" : chip.modelData)
                        }
                    }
                }
            }
        }
    }

    // Preview of one scheme: a mini surface with the palette's key roles.
    component SwatchStrip: Item {
        id: strip
        property var colorMap: null
        readonly property bool ready: colorMap !== null

        function c(role, fallback) {
            return colorMap && colorMap[role] ? colorMap[role] : fallback;
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Styling.radius(0), 14)
            color: strip.c("surfaceContainer", Ui.alpha(Colors.overBackground, 0.06))
            clip: true

            // Shimmer while palettes load
            Rectangle {
                anchors.fill: parent
                visible: !strip.ready
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: Ui.alpha(Colors.overBackground, 0.08)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
                SequentialAnimation on x {
                    running: !strip.ready && SchemePreviews.loading
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -strip.width
                        to: strip.width
                        duration: 1100
                    }
                }
            }

            Rectangle {
                id: hero
                visible: strip.ready
                x: 5
                y: 5
                width: (parent.width - 14) * 0.6
                height: parent.height - 10
                radius: Math.min(Styling.radius(-2), 12)
                color: strip.c("primary", "transparent")
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: "Aa"
                    font.family: Config.theme.font
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: strip.c("overPrimary", "transparent")
                }
            }
            Column {
                visible: strip.ready
                anchors.left: hero.right
                anchors.leftMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 5
                y: 5
                spacing: 4
                Repeater {
                    model: ["secondaryContainer", "tertiary", "surfaceContainerHighest"]
                    Rectangle {
                        required property string modelData
                        width: parent.width
                        height: (strip.height - 10 - 8) / 3
                        radius: Math.min(Styling.radius(-6), 8)
                        color: strip.c(modelData, "transparent")
                    }
                }
            }
        }
    }
}
