pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// The search field of a list screen (launcher, its tabs, pickers): no box,
// the query large and light (title size, regular weight) with a calm
// fading caret, a muted leading glyph (`glyph`: the search glyph, or the
// active mode's icon) and trailing key hints (`hints: ["cc", "="]`, shown
// while the field is empty). Same keyboard API as SearchInput; `prefixIcon`
// (a tab's mode) becomes the glyph. `rule: true` draws the Divider under it.
SearchInput {
    id: root

    property string glyph: root.prefixIcon !== "" ? root.prefixIcon : Icons.magnifyingGlass
    property var hints: []
    property bool rule: false

    variant: "transparent"
    radius: 0
    padding: 0
    implicitHeight: Space.rowHeight

    field.font.family: Type.family("title")
    field.font.pixelSize: Type.size("title")
    field.font.weight: Font.Normal
    field.color: Type.text
    field.placeholderTextColor: Type.muted
    field.selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
    field.selectedTextColor: Type.text
    field.leftPadding: 0
    field.rightPadding: 0
    field.cursorDelegate: caret

    leading: Component {
        Text {
            text: root.glyph
            font.family: Icons.font
            font.pixelSize: Type.iconSize("title")
            color: Type.muted
        }
    }

    trailing: Component {
        Row {
            spacing: Space.xs
            visible: root.text.length === 0 && root.hints.length > 0

            Repeater {
                model: root.hints
                KeyHint {
                    required property string modelData
                    text: modelData
                }
            }
        }
    }

    Divider {
        anchors.bottom: parent.bottom
        width: parent.width
        visible: root.rule && Look.dividers
    }

    // A thin caret that breathes instead of blinking hard.
    Component {
        id: caret
        Rectangle {
            width: 2
            radius: 1
            color: Type.secondary
            visible: root.field.cursorVisible

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.field.cursorVisible && Motion.enter.duration > 0
                NumberAnimation {
                    from: 1
                    to: 0.15
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.15
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
