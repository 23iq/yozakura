pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Font family picker (searchable list, each family drawn in itself) +
// size stepper + a live sample in the chosen font.
Item {
    id: root

    property string family: ""
    property int size: 14
    property bool monospace: false
    // Shown when no family is set (e.g. "keep the app's own font")
    property string placeholder: ""
    property string sizeUnit: "px"
    signal familyPicked(string family)
    signal sizeEdited(int size)

    implicitWidth: 480
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: Space.m

        Row {
            width: parent.width
            spacing: Space.s

            Item {
                id: pickButton
                objectName: "fontPickButton"
                width: parent.width - sizeStepper.width - parent.spacing
                height: Space.controlS
                activeFocusOnTab: true
                Keys.onReturnPressed: picker.open()
                Keys.onSpacePressed: picker.open()

                FieldBox {
                    anchors.fill: parent
                    hovered: buttonArea.containsMouse || pickButton.activeFocus
                    focused: picker.opened
                }
                KitText {
                    anchors.left: parent.left
                    anchors.leftMargin: Space.m
                    anchors.right: caret.left
                    anchors.rightMargin: Space.s
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    text: root.family !== "" ? root.family : root.placeholder
                    font.family: root.family !== "" ? root.family : Type.bodyFont
                    font.italic: root.family === ""
                    color: root.family !== "" ? Type.text : Type.muted
                }
                Text {
                    id: caret
                    anchors.right: parent.right
                    anchors.rightMargin: Space.m
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: Type.muted
                }
                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.opened ? picker.close() : picker.open()
                }
            }

            NumberControl {
                id: sizeStepper
                anchors.verticalCenter: parent.verticalCenter
                value: root.size
                from: 8
                to: 32
                unit: root.sizeUnit
                onChanged: v => root.sizeEdited(Math.round(v))
            }
        }

        // Live sample, in the language's control box.
        Item {
            width: parent.width
            height: sample.implicitHeight + Space.l * 2
            clip: true

            ControlBox {
                radius: Look.chipRadius(Space.chip)
            }

            Column {
                id: sample
                x: Space.l
                y: Space.l
                width: parent.width - Space.l * 2
                spacing: Space.xs

                Text {
                    visible: !root.monospace
                    width: parent.width
                    text: "夜桜 Yozakura"
                    font.family: root.family
                    font.pixelSize: root.size * 1.9
                    font.weight: Font.Bold
                    color: Type.text
                    elide: Text.ElideRight
                }
                Text {
                    visible: !root.monospace
                    width: parent.width
                    text: "The quick brown fox jumps over the lazy dog — 0123456789"
                    font.family: root.family
                    font.pixelSize: root.size
                    color: Type.secondary
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: root.monospace
                    width: parent.width
                    textFormat: Text.StyledText
                    text: "<font color='" + Colors.tertiary + "'>fn</font> <font color='" + Colors.primary + "'>bloom</font>(petals: <font color='" + Colors.secondary + "'>u8</font>) -&gt; Sakura {<br>&nbsp;&nbsp;&nbsp;&nbsp;<font color='" + Colors.outline + "'>// 夜桜 0x2A != O0 il1 {}[]</font><br>}"
                    font.family: root.family
                    font.pixelSize: root.size
                    color: Type.text
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    function openPicker() {
        picker.open();
    }

    FontPickerPopup {
        id: picker
        objectName: "fontPicker"
        parent: pickButton
        y: pickButton.height + Space.xs
        width: pickButton.width
        family: root.family
        monoOnly: root.monospace
        onPicked: f => root.familyPicked(f)
    }
}
