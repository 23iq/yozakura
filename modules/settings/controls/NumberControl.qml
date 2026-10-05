pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// Stepper: [-] value [+]. `changed(value)` with the clamped new value.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string unit: ""
    property var specialValues: []
    signal changed(real value)

    implicitWidth: 132
    implicitHeight: 34
    activeFocusOnTab: true

    function step(dir) {
        const v = Ui.snap(value + dir * stepSize, from, to, stepSize);
        if (v !== value)
            changed(v);
    }

    Keys.onLeftPressed: step(-1)
    Keys.onDownPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: step(1)

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(0), height / 2)
        color: Ui.alpha(Colors.overBackground, 0.06)
        border.width: root.activeFocus ? 2 : 0
        border.color: Colors.primary
    }

    Repeater {
        model: [-1, 1]

        delegate: Item {
            id: btn
            required property int modelData
            width: 30
            height: 30
            y: (root.height - height) / 2
            x: btn.modelData < 0 ? 2 : root.width - width - 2
            readonly property bool atLimit: btn.modelData < 0 ? root.value <= root.from : root.value >= root.to

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: area.containsMouse && !btn.atLimit ? Ui.alpha(Colors.overBackground, 0.14) : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: btn.modelData < 0 ? Icons.minus : Icons.plus
                font.family: Icons.font
                font.pixelSize: 14
                color: Colors.overBackground
                opacity: btn.atLimit ? 0.3 : 1
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.forceActiveFocus();
                    root.step(btn.modelData);
                }
                onPressAndHold: repeatTimer.start()
                onReleased: repeatTimer.stop()
            }
            Timer {
                id: repeatTimer
                interval: 70
                repeat: true
                onTriggered: root.step(btn.modelData)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Ui.formatValue(root.value, root.unit, root.specialValues, I18n.t)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.DemiBold
        font.features: {
            "tnum": 1
        }
        color: Colors.overBackground
    }
}
