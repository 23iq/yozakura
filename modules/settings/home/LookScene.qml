pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Look: a big "Aa" in the UI's heading font with the
// font's name beside it, and the palette as one strip of swatches along the
// foot of the scene (what the destination changes: type and colour).
Item {
    id: scene

    required property Card tile

    readonly property string fontName: String(SettingsStore.get("theme.font") || Type.family("body"))

    Row {
        id: type
        spacing: Space.l

        KitText {
            id: glyphs
            role: "display"
            font.family: Type.family("title")
            font.pixelSize: Math.round(Math.min(scene.height * 0.55, Type.size("display") * 1.9))
            font.weight: Font.DemiBold
            color: Type.accent
            text: "Aa"
        }
        KitText {
            anchors.baseline: glyphs.baseline
            width: Math.max(0, scene.width - glyphs.width - type.spacing)
            role: "secondary"
            text: scene.fontName
            elide: Text.ElideRight
        }
    }

    Row {
        id: palette
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.round(Math.max(Space.controlS, Math.min(Space.controlL, scene.height * 0.22)))
        spacing: Space.xs
        readonly property var swatches: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.primaryContainer, Colors.tertiaryContainer]
        Repeater {
            model: palette.swatches
            delegate: Mark {
                required property color modelData
                width: (palette.width - palette.spacing * (palette.swatches.length - 1)) / palette.swatches.length
                height: palette.height
                radius: Look.radius("small", height)
                color: modelData
            }
        }
    }
}
