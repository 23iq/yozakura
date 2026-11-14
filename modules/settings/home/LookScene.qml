pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Look: a big "Aa" in the UI's heading font with the
// font's name on the same baseline beside it, standing on the palette (one
// strip of swatches along the foot of the scene): what the destination
// changes, type and colour. The "Aa" is as tall as the room above the strip
// allows, so the scene has no dead gap at any tile size.
Item {
    id: scene

    required property Card tile

    readonly property string fontName: String(SettingsStore.get("theme.font") || Type.family("body"))
    // the room above the strip, where the type stands
    readonly property real typeRoom: Math.max(0, palette.y - Space.m)

    KitText {
        id: glyphs
        role: "display"
        font.family: Type.family("title")
        // a line box is about 1.25 of the size: fill the room, not more
        font.pixelSize: Math.max(Type.size("title"), Math.round(Math.min(scene.typeRoom / 1.25, Type.size("display") * 2.6)))
        font.weight: Font.DemiBold
        color: Type.accent
        text: "Aa"
        // its baseline a little above the strip (descender room only)
        y: Math.round(scene.typeRoom - glyphs.baselineOffset - Space.xs)
    }
    KitText {
        x: glyphs.width + Space.l
        anchors.baseline: glyphs.baseline
        width: Math.max(0, scene.width - x)
        role: "secondary"
        text: scene.fontName
        elide: Text.ElideRight
    }

    Row {
        id: palette
        y: scene.height - height
        width: parent.width
        height: Math.round(Math.max(Space.controlS, Math.min(Space.controlL, scene.height * 0.26)))
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
                border.width: Look.cardEdge.a > 0 ? Space.hairline : 0
                border.color: Look.cardEdge
            }
        }
    }
}
