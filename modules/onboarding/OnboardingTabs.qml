pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Segmented tabs [{id, icon, label}]; the highlight glides to `current`.
StyledRect {
    id: root

    property var tabs: []
    property string current: ""
    signal picked(string id)

    readonly property int currentIndex: Math.max(0, tabs.findIndex(t => t.id === current))

    variant: "common"
    enableShadow: false
    radius: Math.min(height / 2, Styling.radius(2))
    implicitHeight: Math.round(Styling.fontSize(0) * 2.6)
    implicitWidth: segments.implicitWidth + 8

    StyledRect {
        id: highlight
        readonly property Item target: repeater.count > root.currentIndex ? repeater.itemAt(root.currentIndex) : null
        variant: "focus"
        enableShadow: false
        y: 4
        height: parent.height - 8
        x: 4 + (target ? target.x : 0)
        width: target ? target.width : 0
        radius: Math.min(height / 2, Styling.radius(1))
        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    Row {
        id: segments
        x: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: repeater
            model: root.tabs

            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool on: tab.index === root.currentIndex

                objectName: "tab:" + tab.modelData.id
                width: content.implicitWidth + Math.round(Styling.fontSize(0) * 2)
                height: root.height - 8
                activeFocusOnTab: true
                Keys.onReturnPressed: root.picked(tab.modelData.id)
                Keys.onSpacePressed: root.picked(tab.modelData.id)

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons[tab.modelData.icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(0)
                        color: tab.on ? Colors.primary : Colors.overSurfaceVariant
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: tab.on ? Font.DemiBold : Font.Medium
                        color: tab.on ? Colors.overBackground : Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(tab.modelData.id)
                }
            }
        }
    }
}
