pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles
import "../Ui.js" as Ui

// Active workspace indicator picker (workspaces.indicatorStyle): one chip
// per registered style (IndicatorStyles.js), each showing a 3-slot strip
// with the real indicator component on slot 2.
Item {
    id: root

    property var entry
    readonly property string current: SettingsStore.get("workspaces.indicatorStyle") || IndicatorStyles.DEFAULT_ID
    readonly property real slot: 24

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: parent.width
        spacing: 8

        Repeater {
            model: IndicatorStyles.ids()

            delegate: Rectangle {
                id: chip
                required property string modelData
                readonly property var style: IndicatorStyles.get(modelData)
                readonly property bool selected: root.current === modelData

                objectName: "indicatorChip:" + modelData
                width: strip.width + caption.implicitWidth + 30
                height: root.slot + 16
                radius: height / 2
                color: selected ? Ui.alpha(Colors.primary, 0.14) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : Ui.alpha(Colors.overBackground, 0.035))
                border.width: selected || activeFocus ? 2 : 1
                border.color: selected || activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.8)
                activeFocusOnTab: true
                Keys.onSpacePressed: SettingsStore.set("workspaces.indicatorStyle", modelData)
                Keys.onReturnPressed: SettingsStore.set("workspaces.indicatorStyle", modelData)
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

                    // Fake ActiveIndicator for the style component.
                    QtObject {
                        id: fakeIndicator
                        readonly property bool vertical: false
                        readonly property real width: root.slot
                        readonly property real height: root.slot
                        readonly property real slotSize: root.slot
                        readonly property real padding: 0
                        readonly property bool occupied: true
                        readonly property real baseRadius: Styling.radius(0)
                        readonly property int workspaceId: 2
                    }

                    Loader {
                        x: root.slot
                        source: Qt.resolvedUrl("../../bar/workspaces/indicators/" + chip.style.component)
                        onLoaded: item.indicator = fakeIndicator
                    }

                    Row {
                        Repeater {
                            model: 3
                            Text {
                                required property int index
                                width: root.slot
                                height: root.slot
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: index + 1
                                font.family: Config.theme.font
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: index !== 1 ? Colors.overBackground : (chip.style.filled ? Styling.srItem("primary") : Colors.primary)
                            }
                        }
                    }
                }

                Text {
                    id: caption
                    anchors.left: strip.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("prefs.indicator." + chip.modelData)
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
                    onClicked: SettingsStore.set("workspaces.indicatorStyle", chip.modelData)
                }
            }
        }
    }
}
