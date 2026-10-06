pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.store
import "../Ui.js" as Ui

// Kitty cursor shape (terminal.cursorShape): one chip per shape, each
// drawing that cursor after a letter in the terminal font.
Row {
    id: root

    property var entry
    readonly property string value: SettingsStore.get("terminal.cursorShape") ?? "beam"
    readonly property var shapes: ["block", "beam", "underline"]

    spacing: 8

    Repeater {
        model: root.shapes

        delegate: Item {
            id: chip
            required property string modelData
            readonly property bool selected: root.value === modelData

            objectName: "cursorChip:" + modelData
            width: label.implicitWidth + 64
            height: 40
            activeFocusOnTab: true
            Keys.onSpacePressed: SettingsStore.set("terminal.cursorShape", chip.modelData)
            Accessible.role: Accessible.RadioButton
            Accessible.name: label.text
            Accessible.checked: chip.selected

            Rectangle {
                anchors.fill: parent
                radius: Math.min(Styling.radius(2), 20)
                color: chip.selected ? Ui.alpha(Colors.primary, 0.14) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : Ui.alpha(Colors.overBackground, 0.04))
                border.width: chip.selected || chip.activeFocus ? 2 : 1
                border.color: chip.selected || chip.activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.8)
            }

            // "a" + the cursor, on a terminal-colored cell
            Rectangle {
                id: cell
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 24
                radius: 6
                color: Colors.background

                Text {
                    id: glyph
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: "a"
                    font.family: TerminalLookService.fontFamily
                    font.pixelSize: 13
                    color: Colors.overSurface
                }
                Rectangle {
                    x: glyph.x + glyph.implicitWidth + 1
                    y: chip.modelData === "underline" ? 18 : 5
                    width: chip.modelData === "block" ? 8 : (chip.modelData === "beam" ? 2 : 9)
                    height: chip.modelData === "underline" ? 2 : 15
                    color: chip.selected ? Colors.primary : Colors.overSurface
                }
            }

            Text {
                id: label
                anchors.left: cell.right
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("prefs.term.look.cursor." + chip.modelData)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: chip.selected ? Font.DemiBold : Font.Normal
                color: chip.selected ? Colors.primary : Colors.overBackground
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.set("terminal.cursorShape", chip.modelData)
            }
        }
    }
}
