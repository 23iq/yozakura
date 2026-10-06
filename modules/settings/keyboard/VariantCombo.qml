pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui

// Compact dropdown over options [{value, label}] (a layout's variants can be
// dozens, too wide for segmented chips).
Item {
    id: root

    property var options: []
    property string value: ""
    signal selected(string value)

    readonly property var current: options.find(o => o.value === value) ?? options[0] ?? null

    implicitWidth: Math.min(Math.max(row.implicitWidth + 28, 190), 300)
    implicitHeight: 34
    activeFocusOnTab: true
    Keys.onReturnPressed: popup.open()
    Keys.onSpacePressed: popup.open()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Ui.alpha(Colors.overBackground, area.containsMouse || popup.opened ? 0.1 : 0.05)
        border.width: root.activeFocus ? 2 : 1
        border.color: popup.opened || root.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
    }
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        width: parent.width - 28
        spacing: 8
        Text {
            width: parent.width - caret.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? root.current.label : ""
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
        }
        Text {
            id: caret
            anchors.verticalCenter: parent.verticalCenter
            text: popup.opened ? Icons.caretUp : Icons.caretDown
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.opened ? popup.close() : popup.open()
    }

    Popup {
        id: popup
        y: root.height + 6
        width: Math.max(root.width, 260)
        height: Math.min(list.contentHeight, 260) + 12
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(2)
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Item {
                id: opt
                required property var modelData
                required property int index
                readonly property bool on: opt.modelData.value === root.value
                width: ListView.view.width
                height: 34
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: opt.on ? Ui.alpha(Colors.primary, 0.22) : (optArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : "transparent")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    width: parent.width - 28
                    text: opt.modelData.label
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: opt.on ? Font.DemiBold : Font.Normal
                    color: Colors.overBackground
                }
                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        popup.close();
                        root.selected(opt.modelData.value);
                    }
                }
            }
        }
    }
}
