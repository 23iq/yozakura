pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.components.kit
import "SegmentGlyphs.js" as SegmentGlyphs

// A seven-segment readout ("21:05", "62", "-3.5"): every cell draws all
// seven bars, the lit ones in `color`, the rest as dim "off" segments in the
// same colour (`offOpacity`), like an LCD. ":" and "." are narrow dots
// between cells; letters SegmentGlyphs knows (A-F, H, L, O, P, U) render,
// anything else is a blank cell. Sized by `digitHeight` (the cell is ~0.55
// of it wide); `pixelSize` sets it from a type size. Lit segments fade
// (Motion.micro). Colours come from the caller (default: the live value,
// Type.accent), never from the palette directly here.
Item {
    id: root

    property string text: ""
    property real digitHeight: Type.size("display")
    property color color: Type.accent
    property real offOpacity: 0.08
    property real thickness: Math.max(1.5, root.digitHeight * 0.13)
    readonly property real digitWidth: Math.round(root.digitHeight * 0.58)
    readonly property real spacing: Math.max(2, Math.round(root.digitHeight * 0.18))
    readonly property real dotWidth: root.thickness
    readonly property color offColor: Qt.alpha(root.color, root.offOpacity)

    implicitWidth: row.implicitWidth
    implicitHeight: root.digitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    Row {
        id: row
        spacing: root.spacing

        Repeater {
            // By index, so cells (and their fades) survive a text change.
            model: root.text.length

            Item {
                id: cell
                required property int index
                readonly property string ch: root.text.charAt(cell.index)
                readonly property bool separator: SegmentGlyphs.isSeparator(cell.ch)
                readonly property var lit: SegmentGlyphs.mask(cell.ch)

                width: cell.separator ? root.dotWidth : root.digitWidth
                height: root.digitHeight

                // ":" two dots, "." one at the baseline.
                Repeater {
                    model: cell.separator ? (cell.ch === ":" ? [0.3, 0.7] : [1]) : []

                    Rectangle {
                        required property real modelData
                        width: root.dotWidth
                        height: root.dotWidth
                        radius: width / 2
                        y: Math.min(root.digitHeight - height, root.digitHeight * modelData - height / 2)
                        color: root.color
                    }
                }

                Repeater {
                    model: cell.separator ? 0 : 7

                    Shape {
                        id: bar
                        required property int index
                        readonly property bool on: cell.lit[bar.index]
                        property color fill: bar.on ? root.color : root.offColor
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        Behavior on fill {
                            enabled: Motion.micro.duration > 0
                            ColorAnimation {
                                duration: Motion.micro.duration
                            }
                        }

                        ShapePath {
                            fillColor: bar.fill
                            strokeColor: "transparent"
                            PathPolyline {
                                path: SegmentGlyphs.polygon(bar.index, root.digitWidth, root.digitHeight, root.thickness).map(p => Qt.point(p[0], p[1]))
                            }
                        }
                    }
                }
            }
        }
    }
}
