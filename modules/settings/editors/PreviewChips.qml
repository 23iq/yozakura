pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../Ui.js" as Ui

// One-of picker drawn as chips, each with a small live preview strip (3
// slots of `slot` px on the background) and a caption. `preview` is
// instantiated per chip; its root gets `chipId` (the option) set.
Item {
    id: root

    required property string key
    required property var ids
    required property string current
    // Caption: I18n.t(labelPrefix + id); objectName: namePrefix + id.
    required property string labelPrefix
    required property string namePrefix
    required property Component preview
    property real slot: 24

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: parent.width
        spacing: 8

        Repeater {
            model: root.ids

            delegate: Rectangle {
                id: chip
                required property string modelData
                readonly property bool selected: root.current === modelData

                objectName: root.namePrefix + modelData
                width: strip.width + caption.implicitWidth + 30
                height: root.slot + 16
                radius: height / 2
                color: selected ? Ui.alpha(Colors.primary, 0.14) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : Ui.alpha(Colors.overBackground, 0.035))
                border.width: selected || activeFocus ? 2 : 1
                border.color: selected || activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.8)
                activeFocusOnTab: true
                Keys.onSpacePressed: SettingsStore.set(root.key, modelData)
                Keys.onReturnPressed: SettingsStore.set(root.key, modelData)
                Accessible.role: Accessible.RadioButton
                Accessible.name: caption.text
                Accessible.checked: selected

                Rectangle {
                    id: strip
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.slot * 3
                    height: root.slot
                    radius: height / 2
                    color: Colors.background

                    Loader {
                        anchors.fill: parent
                        sourceComponent: root.preview
                        onLoaded: item.chipId = chip.modelData
                    }
                }

                Text {
                    id: caption
                    anchors.left: strip.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t(root.labelPrefix + chip.modelData)
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
                    onClicked: SettingsStore.set(root.key, chip.modelData)
                }
            }
        }
    }
}
