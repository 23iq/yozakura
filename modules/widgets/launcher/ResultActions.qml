pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The actions of a result ([{id, text, icon, variant}] from its provider) as
// compact kit ListRows: under an expanded row (Shift+Enter / right click,
// `currentIndex` is the keyboard cursor) and in the detail pane. The main
// action (id "") carries the ↵ key; a destructive one ("error") an error glyph.
Column {
    id: actions

    property var options: []
    property int currentIndex: -1
    property bool showKeys: true

    signal hovered(int index)
    signal triggered(int index)

    Repeater {
        model: actions.options

        ListRow {
            id: option
            required property var modelData
            required property int index
            readonly property bool main: modelData.id === ""

            width: actions.width
            height: Space.controlS
            title: modelData.text || ""
            highlighted: actions.currentIndex === index
            onClicked: actions.triggered(index)
            onHoveredChanged: {
                if (hovered && !highlighted)
                    actions.hovered(index);
            }

            leading: Component {
                Text {
                    width: Type.iconSize("body")
                    horizontalAlignment: Text.AlignHCenter
                    text: option.modelData.icon || ""
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: option.modelData.variant === "error" ? Colors.error : Type.secondary
                }
            }

            trailing: Component {
                KeyHint {
                    visible: actions.showKeys && option.main
                    icon: Icons.arrowElbowDownLeft
                }
            }
        }
    }
}
