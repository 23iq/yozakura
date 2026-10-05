import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components

// Small round glyph button for activity rows (open folder, pause, cancel,
// stop). `tone` picks the glyph color role.
StyledRect {
    id: button

    property string icon: ""
    property string tooltip: ""
    property string tone: "overBackground"

    signal clicked

    variant: mouse.containsMouse ? "focus" : "common"
    enableBorder: false
    readonly property real size: Math.round(Styling.fontSize(0) + 10)
    implicitWidth: size
    implicitHeight: size
    radius: size / 2

    Text {
        anchors.centerIn: parent
        text: button.icon
        font.family: Icons.font
        font.pixelSize: Math.round(button.size * 0.5)
        color: {
            const c = Colors[button.tone];
            return c !== undefined ? c : Colors.overBackground;
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    StyledToolTip {
        show: mouse.containsMouse
        tooltipText: button.tooltip
    }
}
