import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

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

    Rectangle {
        x: 20
        width: parent.width - 40
        height: 1
        visible: row.separator
        color: Ui.alpha(Colors.outlineVariant, 0.45)
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        visible: row.dragging
        color: Ui.alpha(Colors.primary, 0.1)
    }

    Item {
        id: gripBox
        x: 12
        width: 28
        height: parent.height
        visible: row.count > 1

        Text {
            anchors.centerIn: parent
            text: Icons.list
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(2)
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

    LayoutBadge {
        id: badge
        x: 52
        anchors.verticalCenter: parent.verticalCenter
        code: row.code
        lit: row.active
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 14
        anchors.right: variantBox.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Row {
            spacing: 8
            Text {
                text: row.description || row.code
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }
            Rectangle {
                visible: row.active
                anchors.verticalCenter: parent.verticalCenter
                width: activeLabel.implicitWidth + 14
                height: 18
                radius: 9
                color: Ui.alpha(Colors.tertiary, 0.2)
                Text {
                    id: activeLabel
                    anchors.centerIn: parent
                    text: I18n.t("prefs.keyboard.active")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.DemiBold
                    color: Colors.tertiary
                }
            }
        }
        Text {
            text: row.code + (row.variant !== "" ? "  ·  " + row.variant : "")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }

    Item {
        id: variantBox
        anchors.right: removeButton.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: combo.visible ? combo.width : 0
        height: combo.height
        VariantCombo {
            id: combo
            objectName: "variantCombo"
            visible: row.variantChoices.length > 1
            variants: row.variantChoices
            chosen: row.variant
            onPicked: v => row.variantPicked(v)
        }
    }

    Item {
        id: removeButton
        objectName: "removeButton"
        anchors.right: parent.right
        anchors.rightMargin: 20
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
        Text {
            anchors.centerIn: parent
            text: Icons.trash
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(1)
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
