pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

// One keyboard key drawn as a keycap: a face over a darker bottom edge.
// `cap` is {kind, text, icon} from modules/keybinds/KeyNames.js:
//   "super" - the app's Super-key glyph (assets/yozakura/super-key.svg)
//             tinted with `glyphColor`;
//   "icon"  - an Icons glyph (arrows, enter, mouse buttons, media keys)
//             with an optional small `text` hint;
//   "text"  - a short label.
// Sizes follow the font size (`sizeOffset` as in Styling.fontSize) and the
// corner radius follows the theme roundness.
Item {
    id: root

    property var cap: ({
            "kind": "text",
            "text": "",
            "icon": ""
        })
    property int sizeOffset: -2
    // "normal" | "accent" (recording, selection) | "error" (conflict)
    property string tone: "normal"
    property color glyphColor: tone === "accent" ? Colors.overPrimaryContainer : Colors.primary

    readonly property real fontPx: Styling.fontSize(root.sizeOffset)
    readonly property real capHeight: Math.round(fontPx * 1.85)
    readonly property real edge: Math.max(1, Math.round(capHeight / 12))
    readonly property real pad: Math.round(fontPx * 0.5)
    readonly property color faceColor: tone === "accent" ? Colors.primaryContainer : (tone === "error" ? Colors.errorContainer : Colors.surfaceContainerHighest)
    readonly property color edgeColor: tone === "accent" ? Colors.primary : (tone === "error" ? Colors.error : Colors.outlineVariant)
    readonly property color labelColor: tone === "accent" ? Colors.overPrimaryContainer : (tone === "error" ? Colors.overErrorContainer : Colors.overSurface)
    readonly property string kind: cap && cap.kind ? cap.kind : "text"

    implicitHeight: capHeight + edge
    implicitWidth: Math.max(capHeight, content.implicitWidth + pad * 2)

    Accessible.role: Accessible.StaticText
    Accessible.name: kind === "super" ? "Super" : (cap.text || cap.icon || "")

    // Bottom edge (key depth)
    Rectangle {
        anchors.fill: parent
        radius: face.radius
        color: root.edgeColor
    }

    Rectangle {
        id: face
        width: parent.width
        height: root.capHeight
        radius: Math.min(Styling.radius(-6), root.capHeight * 0.32)
        color: root.faceColor
        border.width: 1
        border.color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, 0.55)

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Math.round(root.fontPx * 0.2)

            Image {
                id: superGlyph
                visible: root.kind === "super"
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? Math.round(root.capHeight * 0.78) : 0
                height: width
                source: visible ? Qt.resolvedUrl("../../assets/yozakura/super-key.svg") : ""
                sourceSize.width: Math.max(16, width * 2)
                sourceSize.height: Math.max(16, height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                layer.enabled: visible
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: root.glyphColor
                }
            }

            Text {
                visible: root.kind === "icon"
                anchors.verticalCenter: parent.verticalCenter
                text: root.kind === "icon" ? (Icons[root.cap.icon] ?? "") : ""
                font.family: Icons.font
                font.pixelSize: Math.round(root.fontPx * 1.05)
                color: root.labelColor
            }

            Text {
                visible: text !== "" && root.kind !== "super"
                anchors.verticalCenter: parent.verticalCenter
                text: root.cap && root.cap.text ? root.cap.text : ""
                font.family: Config.theme.font
                font.pixelSize: root.kind === "icon" ? Math.round(root.fontPx * 0.8) : root.fontPx
                font.weight: Font.DemiBold
                color: root.labelColor
            }
        }
    }
}
