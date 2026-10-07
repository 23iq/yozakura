pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One emoji of the list: a kit ListRow (the glyph leading, its name) and,
// when expanded, its skin tones as compact ListRows (the keyboard cursor is
// the tab's selectedOptionIndex). Click copies, or opens the tones of an
// emoji that has them; the selected row shows what Enter does.
Item {
    id: er

    required property var tab
    required property var entry
    required property int index
    property int rowHeight: Space.rowHeight
    property int optionHeight: Space.controlS
    readonly property bool tones: !!er.entry.skin_tone_support
    readonly property bool expanded: er.tab.expandedItemIndex === er.index && er.tones
    readonly property bool selected: er.tab.selectedIndex === er.index

    height: er.rowHeight + (er.expanded ? er.tab.skinTones.length * er.optionHeight : 0)

    function glyphSize(h) {
        return Math.round(h * 0.5);
    }

    ListRow {
        id: row
        width: parent.width
        height: er.rowHeight
        title: er.entry.name || ""
        selected: er.selected
        onClicked: {
            if (er.tones)
                er.tab.toggleOptions(er.index, false);
            else
                er.tab.copyEmoji(er.entry);
        }
        onHoveredChanged: {
            if (hovered && !er.selected && er.tab.expandedItemIndex === -1)
                er.tab.selectedIndex = er.index;
        }

        leading: Component {
            Text {
                width: Metrics.iconSize
                horizontalAlignment: Text.AlignHCenter
                text: er.entry.emoji || ""
                font.pixelSize: er.glyphSize(Metrics.iconSize * 1.25)
                color: Type.text
            }
        }

        trailing: Component {
            Row {
                spacing: Space.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: er.tones
                    text: er.expanded ? Icons.caretUp : Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: Type.muted
                }

                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: er.selected && !er.expanded
                    icon: Icons.arrowElbowDownLeft
                }
            }
        }
    }

    Column {
        y: er.rowHeight
        width: parent.width
        visible: er.expanded

        Repeater {
            model: er.expanded ? er.tab.skinTones : []

            ListRow {
                id: tone
                required property var modelData
                required property int index

                width: parent.width
                height: er.optionHeight
                title: tone.modelData.name
                highlighted: er.tab.selectedOptionIndex === tone.index
                onClicked: er.tab.copyEmoji(er.entry, tone.modelData.modifier)
                onHoveredChanged: {
                    if (hovered && !highlighted) {
                        er.tab.selectedOptionIndex = tone.index;
                        er.tab.keyboardNavigation = false;
                    }
                }

                leading: Component {
                    Text {
                        width: Metrics.iconSize
                        horizontalAlignment: Text.AlignHCenter
                        text: (er.entry.emoji || "") + tone.modelData.modifier
                        font.pixelSize: er.glyphSize(er.optionHeight)
                        color: Type.text
                    }
                }

                trailing: Component {
                    KeyHint {
                        visible: tone.highlighted
                        icon: Icons.arrowElbowDownLeft
                    }
                }
            }
        }
    }
}
