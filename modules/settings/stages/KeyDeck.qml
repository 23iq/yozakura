pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit
import "KeyDeck.js" as Deck

// A keyboard drawn from keycaps (the Keys destination's stage; the home
// tile's keycaps grown up): five rows of a compact keyboard, the keys in
// `lit` (KeyDeck.js ids) raised in the accent, a lit key settling in with
// a short press. `badge`: the layout's short name on the space bar. The
// Super keys wear the app's Super glyph (the list keycaps' flower). The keys
// sit on their own case (`plate`, an opaque surface): a wallpaper behind
// the stage never shows through between them.
Item {
    id: deck

    property var lit: []
    property string badge: ""
    property bool plate: true
    readonly property real gap: Math.max(2, Math.round(deck.unit * 0.12))
    readonly property real unit: Math.min(deck.width / Deck.UNITS, deck.height / 5 / 0.95)
    readonly property real capH: deck.unit * 0.95 - deck.gap

    implicitHeight: Space.controlL * 3

    // the keyboard's case
    Mark {
        visible: deck.plate
        anchors.centerIn: keys
        width: keys.width + deck.gap * 4
        height: keys.height + deck.gap * 4
        radius: Look.radius("box", height) * 0.6
        color: Colors.surfaceContainer
        border.width: Space.hairline
        border.color: Look.cardEdge
    }

    Column {
        id: keys
        anchors.centerIn: parent
        spacing: deck.gap
        Repeater {
            model: Deck.ROWS
            delegate: Row {
                id: keyRow
                required property var modelData
                spacing: deck.gap
                Repeater {
                    model: keyRow.modelData
                    delegate: Mark {
                        id: cap
                        required property var modelData
                        readonly property bool on: deck.lit.indexOf(cap.modelData[0]) >= 0
                        objectName: "keycap:" + cap.modelData[0]
                        width: cap.modelData[2] * deck.unit - deck.gap
                        height: deck.capH
                        radius: Look.radius("box", height) * 0.6
                        color: cap.on ? Type.accent : Look.raisedFill(false)
                        border.width: Space.hairline
                        border.color: Qt.alpha(Colors.shadow, 0.35)
                        scale: cap.on ? 0.96 : 1
                        Behavior on scale {
                            enabled: Motion.spring.duration > 0
                            NumberAnimation {
                                duration: Motion.spring.duration
                                easing.type: Motion.spring.easing
                            }
                        }
                        Behavior on color {
                            enabled: Motion.micro.duration > 0
                            ColorAnimation {
                                duration: Motion.micro.duration
                            }
                        }
                        // Super: the app's glyph, as on the list's keycaps
                        Image {
                            visible: cap.modelData[0] === "SUPER"
                            anchors.centerIn: parent
                            width: visible ? Math.round(Math.min(cap.height, cap.width) * 0.62) : 0
                            height: width
                            source: visible ? Qt.resolvedUrl("../../../assets/yozakura/super-key.svg") : ""
                            sourceSize.width: Math.max(16, width * 2)
                            sourceSize.height: Math.max(16, height * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                brightness: 1.0
                                colorization: 1.0
                                colorizationColor: cap.on ? Type.accentInk : Type.secondary
                            }
                        }
                        KitText {
                            visible: cap.modelData[0] !== "SUPER"
                            anchors.centerIn: parent
                            width: cap.width - deck.gap * 2
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: Math.round(Type.size("caption") * 0.6)
                            role: cap.modelData[1].length > 1 ? "caption" : "body"
                            font.weight: cap.on ? Type.weight("title") : Type.weight("body")
                            color: cap.on ? Type.accentInk : Type.secondary
                            text: cap.modelData[0] === "space" ? deck.badge : cap.modelData[1]
                            // a cap too small for its name stays blank (never a cut word)
                            opacity: truncated ? 0 : 1
                        }
                    }
                }
            }
        }
    }
}
