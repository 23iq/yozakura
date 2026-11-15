pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Look: everything the destination changes at a glance.
// Your wallpaper with a small card of the visual language on it (its card
// fill and edge, a switch and a slider in the accent); beside it a big "Aa"
// in the UI's heading font, the font's name and the mode (sun / moon) with
// the language's name; the palette as one strip of swatches along the foot.
// A narrow tile keeps the type and the strip only.
Item {
    id: scene

    required property Card tile

    readonly property string fontName: String(SettingsStore.get("theme.font") || Type.family("body"))
    readonly property bool light: SettingsStore.get("theme.lightMode") === true
    readonly property string language: String(SettingsStore.get("theme.language") || "ink")
    // the wallpaper beside the type where there is room for both
    readonly property bool showPicture: scene.width >= Space.px(260) && scene.typeRoom >= Space.px(96)
    // the room above the strip
    readonly property real typeRoom: Math.max(0, palette.y - Space.m)

    // the wallpaper and a card of the language on it
    Item {
        id: picture
        visible: scene.showPicture
        width: scene.showPicture ? Math.round(scene.width * 0.5) : 0
        height: scene.typeRoom

        Art {
            id: art
            anchors.fill: parent
            source: SettingsStore.wallpaper
            radius: Look.radius("small", height)
            icon: Icons.image
        }
        Mark {
            id: card
            x: Math.round((parent.width - width) / 2)
            y: Math.round(parent.height - height - Space.m)
            width: Math.round(parent.width * 0.72)
            height: Math.round(Math.max(Space.controlS, parent.height * 0.34))
            radius: Look.radius("surface", height)
            color: Look.cardFill(false)
            border.width: Look.cardEdge.a > 0 ? Space.hairline : 0
            border.color: Look.cardEdge

            // a switch, on
            Mark {
                id: track
                x: Space.s
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(height * 1.8)
                height: Math.round(Math.min(card.height * 0.36, Space.l))
                radius: Look.squareControls ? Look.radius("small", height) : height / 2
                color: Type.accent
                Mark {
                    anchors.right: parent.right
                    anchors.rightMargin: Space.hairline * 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - Space.hairline * 4
                    height: width
                    radius: Look.squareControls ? Look.radius("small", height) : height / 2
                    color: Type.accentInk
                }
            }
            // a slider, two thirds up
            Item {
                x: track.x + track.width + Space.s
                width: card.width - x - Space.s
                height: card.height
                Mark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Space.stroke
                    color: Type.track
                }
                Mark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.66
                    height: Space.stroke
                    color: Type.accent
                }
                Mark {
                    x: Math.round(parent.width * 0.66 - width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.s + Space.xs
                    height: width
                    color: Type.accent
                }
            }
        }
    }

    // the type: "Aa", the font's name, the mode and the language
    Column {
        id: typeCol
        x: scene.showPicture ? picture.width + Space.l : 0
        width: scene.width - x
        y: Math.round((scene.typeRoom - height) / 2)
        spacing: 0

        KitText {
            id: glyphs
            role: "display"
            font.family: Type.family("title")
            // a line box is about 1.25 of the size: fill the room it has
            font.pixelSize: Math.max(Type.size("title"), Math.round(Math.min((scene.typeRoom - meta.height - fontLabel.height) / 1.25, Type.size("display") * 2.4, typeCol.width / 1.6)))
            font.weight: Font.DemiBold
            color: Type.accent
            text: "Aa"
        }
        KitText {
            id: fontLabel
            width: parent.width
            role: "body"
            font.family: scene.fontName
            text: scene.fontName
            elide: Text.ElideRight
        }
        Row {
            id: meta
            spacing: Space.xs
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: scene.light ? Icons.sun : Icons.moon
                role: "secondary"
                tone: "secondary"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, typeCol.width - Space.l)
                role: "secondary"
                text: I18n.t("prefs.appearance.language." + scene.language)
                elide: Text.ElideRight
            }
        }
    }

    Row {
        id: palette
        y: scene.height - height
        width: parent.width
        height: Math.round(Math.max(Space.controlXS * 0.75, Math.min(Space.controlS, scene.height * 0.18)))
        spacing: Space.xs
        readonly property var swatches: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.primaryContainer, Colors.secondaryContainer, Colors.tertiaryContainer]
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
