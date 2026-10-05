pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Dropdown choosing a preset (or one of `extra` [{value, label}] entries
// such as "defaults"). Shows each preset's mode and style tags.
Item {
    id: root

    property string value: ""
    property var extra: []
    property string placeholder: ""
    signal picked(string value)

    readonly property string label: {
        for (let i = 0; i < extra.length; i++) {
            if (extra[i].value === value)
                return extra[i].label;
        }
        return value || placeholder;
    }

    implicitWidth: 220
    implicitHeight: 36
    activeFocusOnTab: true
    Keys.onReturnPressed: menu.open()
    Keys.onSpacePressed: menu.open()

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Math.min(Styling.radius(0), height / 2)
        color: area.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : Ui.alpha(Colors.overBackground, 0.06)
        border.width: root.activeFocus || menu.visible ? 2 : 1
        border.color: root.activeFocus || menu.visible ? Colors.primary : Ui.alpha(Colors.outline, 0.35)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: caret.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        Text {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.caretDown
            font.family: Icons.font
            font.pixelSize: 12
            color: Colors.overSurfaceVariant
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.open()
        }
    }

    Popup {
        id: menu
        y: root.height + 6
        width: Math.max(root.width, 260)
        height: Math.min(340, list.contentHeight + 16)
        padding: 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Math.min(Styling.radius(2), 18)
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Ui.alpha(Colors.outline, 0.4)
        }

        contentItem: ListView {
            id: list
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.extra.map(e => ({
                        "value": e.value,
                        "label": e.label,
                        "tags": []
                    })).concat(PresetStudio.presets.map(p => ({
                        "value": p.name,
                        "label": p.name,
                        "tags": (p.tags || []).slice(0, 2)
                    })))
            delegate: Rectangle {
                id: opt
                required property var modelData
                width: ListView.view.width
                height: 34
                radius: Math.min(Styling.radius(0), 12)
                color: optArea.containsMouse ? Ui.alpha(Colors.primary, 0.14) : (modelData.value === root.value ? Ui.alpha(Colors.primary, 0.08) : "transparent")
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: tagRow.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: opt.modelData.label
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: opt.modelData.value === root.value ? Font.Bold : Font.Normal
                    color: opt.modelData.value === root.value ? Colors.primary : Colors.overBackground
                }
                Row {
                    id: tagRow
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: opt.modelData.tags
                        PresetChip {
                            required property string modelData
                            text: I18n.t(PresetModel.tagLabel(modelData))
                        }
                    }
                }
                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.close();
                        root.picked(opt.modelData.value);
                    }
                }
            }
        }
    }
}
