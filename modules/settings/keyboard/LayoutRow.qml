import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// One configured layout: drag handle, code badge, name, variant dropdown and
// remove. Reordering is the page's job: dropping the handle `n` rows away
// emits moveBy(n).
Item {
    id: row

    property int count: 1
    property string code: ""
    property string description: ""
    property string variant: ""
    property var variantChoices: []
    property bool active: false
    property bool separator: true

    signal moveBy(int delta)
    signal variantPicked(string variant)
    signal removeRequested

    // Vertical drag offset of the row while its handle is held
    property real dragY: 0
    readonly property bool dragging: grip.pressed

    height: 68
    z: dragging ? 5 : 0
    transform: Translate {
        y: row.dragY
    }

    Divider {
        x: Look.rowInset
        width: parent.width - Look.rowInset * 2
        visible: Look.dividers && (row.separator)
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Space.hairline
        visible: row.dragging
        color: Ui.alpha(Colors.primary, 0.1)
    }

    Item {
        id: gripBox
        x: 12
        width: 28
        height: parent.height
        visible: row.count > 1

        Icon {
            role: "title"
            anchors.centerIn: parent
            icon: Icons.list
            color: grip.pressed || grip.containsMouse ? Colors.primary : Ui.alpha(Colors.overSurfaceVariant, 0.7)
        }
        MouseArea {
            id: grip
            objectName: "grip"
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real startY: 0
            onPressed: mouse => startY = mapToItem(row.parent, mouse.x, mouse.y).y
            onPositionChanged: mouse => {
                if (pressed)
                    row.dragY = Math.max(-row.y, Math.min(row.parent.height - row.height - row.y, mapToItem(row.parent, mouse.x, mouse.y).y - startY));
            }
            onReleased: {
                const delta = Math.round(row.dragY / row.height);
                row.dragY = 0;
                if (delta !== 0)
                    row.moveBy(delta);
            }
        }
    }

    // a narrow row (a row card): no variant picker, no code line
    readonly property bool narrow: row.width < Space.px(420)

    LayoutBadge {
        id: badge
        x: row.narrow ? Space.xxl + Space.m : 52
        anchors.verticalCenter: parent.verticalCenter
        code: row.code
        lit: row.active
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Space.l
        anchors.right: variantBox.left
        anchors.rightMargin: Space.l
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs
        Row {
            spacing: Space.s
            KitText {
                text: row.description || row.code
                font.weight: Font.DemiBold
            }
            // the layout in use: the kit's active chip (the accent marks
            // what is active; a raw amber badge was off the palette)
            Chip {
                objectName: "layoutActive"
                visible: row.active
                anchors.verticalCenter: parent.verticalCenter
                dense: true
                active: true
                Accessible.role: Accessible.StaticText
                text: I18n.t("prefs.keyboard.active")
            }
        }
        KitText {
            role: "caption"
            visible: !row.narrow
            text: row.code + (row.variant !== "" ? "  ·  " + row.variant : "")
            color: Colors.overSurfaceVariant
        }
    }

    Item {
        id: variantBox
        anchors.right: removeButton.left
        anchors.rightMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        width: combo.visible ? combo.width : 0
        height: combo.height
        VariantCombo {
            id: combo
            objectName: "variantCombo"
            visible: row.variantChoices.length > 1 && !row.narrow
            variants: row.variantChoices
            chosen: row.variant
            onPicked: v => row.variantPicked(v)
        }
    }

    Item {
        id: removeButton
        objectName: "removeButton"
        anchors.right: parent.right
        anchors.rightMargin: row.narrow ? 0 : Space.xl
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        opacity: row.count > 1 ? 1 : 0.3
        activeFocusOnTab: row.count > 1
        Keys.onReturnPressed: row.removeRequested()
        Keys.onSpacePressed: row.removeRequested()
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("prefs.keyboard.remove")
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: removeArea.containsMouse && row.count > 1 ? Ui.alpha(Colors.error, 0.18) : "transparent"
            border.width: removeButton.activeFocus ? 2 : 0
            border.color: Colors.primary
        }
        Icon {
            anchors.centerIn: parent
            icon: Icons.trash
            color: removeArea.containsMouse && row.count > 1 ? Colors.error : Colors.overSurfaceVariant
        }
        MouseArea {
            id: removeArea
            anchors.fill: parent
            enabled: row.count > 1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.removeRequested()
        }
    }
}
