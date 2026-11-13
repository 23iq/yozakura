pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.store
import qs.modules.components.kit

// Kitty cursor shape (terminal.cursorShape) as three tiles filling the
// card: each a terminal cell with "ls" typed and that cursor after it, big
// enough to tell block, beam and underline apart; the chosen one ringed.
// Left / Right on keyboard.
FocusScope {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property string value: SettingsStore.get("terminal.cursorShape") ?? "beam"
    readonly property var shapes: [
        {
            "id": "block",
            "label": "prefs.term.look.cursor.block"
        },
        {
            "id": "beam",
            "label": "prefs.term.look.cursor.beam"
        },
        {
            "id": "underline",
            "label": "prefs.term.look.cursor.underline"
        }
    ]
    readonly property int index: Math.max(0, root.shapes.findIndex(s => s.id === root.value))

    implicitWidth: Space.px(300)
    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 2
    activeFocusOnTab: true
    Keys.onLeftPressed: SettingsStore.set("terminal.cursorShape", root.shapes[Math.max(0, root.index - 1)].id)
    Keys.onRightPressed: SettingsStore.set("terminal.cursorShape", root.shapes[Math.min(root.shapes.length - 1, root.index + 1)].id)

    Row {
        width: parent.width
        height: parent.height
        spacing: Space.s

        Repeater {
            model: root.shapes
            delegate: Mark {
                id: tile
                required property var modelData
                readonly property bool chosen: root.value === modelData.id
                readonly property real cellH: Math.round((tile.height - name.implicitHeight - Space.s * 2) * 0.62)
                objectName: "cursorChip:" + modelData.id
                width: (parent.width - Space.s * (root.shapes.length - 1)) / root.shapes.length
                height: parent.height
                radius: Look.radius("box", height)
                color: Look.raisedFill(hit.containsMouse)
                border.width: tile.chosen ? Space.stroke - 1 : Space.hairline
                border.color: tile.chosen ? Type.accent : Type.hairline
                Accessible.role: Accessible.RadioButton
                Accessible.name: name.text
                Accessible.checked: tile.chosen

                // a terminal cell: "ls" and the cursor after it
                Mark {
                    id: cell
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Space.s + ((tile.height - name.implicitHeight - Space.s * 2) - height) / 2
                    width: Math.min(parent.width - Space.s * 2, tile.cellH * 1.8)
                    height: tile.cellH
                    radius: Look.radius("small", height)
                    color: Colors.background
                    KitText {
                        id: glyph
                        x: Space.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ls"
                        font.family: TerminalLookService.fontFamily
                        role: "body"
                        color: Colors.overSurface
                    }
                    Mark {
                        readonly property real ch: glyph.implicitHeight
                        x: glyph.x + glyph.implicitWidth + Space.hairline
                        y: tile.modelData.id === "underline" ? glyph.y + ch * 0.86 : glyph.y + ch * 0.12
                        width: tile.modelData.id === "block" ? ch * 0.55 : (tile.modelData.id === "beam" ? Space.hairline + 1 : ch * 0.55)
                        height: tile.modelData.id === "underline" ? Space.hairline + 1 : ch * 0.8
                        radius: 0
                        color: tile.chosen ? Type.accent : Colors.overSurface
                    }
                }
                KitText {
                    id: name
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Space.s
                    role: "caption"
                    font.weight: tile.chosen ? Look.activeLabelWeight : Look.labelWeight
                    color: tile.chosen ? Type.text : Type.secondary
                    text: I18n.t(tile.modelData.label)
                }
                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsStore.set("terminal.cursorShape", tile.modelData.id)
                }
            }
        }
    }
    FocusRing {
        shown: root.activeFocus
        radius: Look.radius("box", Space.controlL)
    }
}
