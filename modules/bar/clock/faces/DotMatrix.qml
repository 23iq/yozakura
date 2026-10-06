pragma ComponentBehavior: Bound
import QtQuick
import "DotMatrixGlyphs.js" as Glyphs

// LED-style 3x5 dot digits ("21:05"); unlit dots stay faintly visible. A
// vertical bar stacks hours over minutes. Dot size follows the font size.
Item {
    id: root

    required property var clock

    objectName: "faceDotMatrix"
    readonly property real dot: Math.max(2, Math.round(clock.fontSize / 5))
    readonly property real gap: Math.max(1, Math.round(dot / 2))
    readonly property var lines: clock.vertical ? [clock.parts.hours, clock.parts.minutes] : [clock.parts.hours + ":" + clock.parts.minutes]

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        spacing: root.dot * 2

        Repeater {
            model: root.lines

            Row {
                id: line
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.dot + root.gap

                Repeater {
                    model: line.modelData.split("")

                    Grid {
                        id: glyph
                        required property string modelData
                        readonly property bool narrow: modelData === ":"
                        columns: narrow ? 1 : 3
                        spacing: root.gap

                        Repeater {
                            // the colon keeps only its middle column
                            model: Glyphs.glyph(glyph.modelData).filter((d, i) => !glyph.narrow || i % 3 === 1)

                            Rectangle {
                                required property int modelData
                                width: root.dot
                                height: root.dot
                                radius: root.dot / 2
                                color: root.clock.textColor
                                opacity: modelData ? 1 : 0.14
                            }
                        }
                    }
                }
            }
        }
    }
}
