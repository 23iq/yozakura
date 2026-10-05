import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.config

// Edit desktop mode backdrop: a scrim, the snap grid as dots and the depth
// clock's area (widgets placed over it hide the clock).
Item {
    id: root

    property int grid: 24
    property var bounds: null
    property var clockArea: null

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.34
    }

    // Swallow clicks: icons and windows under the backdrop stay untouched.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Canvas {
        id: dots
        anchors.fill: parent
        visible: root.grid > 0
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const b = root.bounds ?? {
                x: 0,
                y: 0,
                w: width,
                h: height
            };
            const step = Math.max(8, root.grid) * (root.grid < 16 ? 2 : 1);
            const c = Colors.overBackground;
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.28);
            for (let x = b.x; x <= b.x + b.w; x += step) {
                for (let y = b.y; y <= b.y + b.h; y += step)
                    ctx.fillRect(Math.round(x) - 1, Math.round(y) - 1, 2, 2);
            }
        }
        Connections {
            target: root
            function onGridChanged() {
                dots.requestPaint();
            }
            function onBoundsChanged() {
                dots.requestPaint();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Rectangle {
        visible: root.clockArea !== null
        x: root.clockArea?.x ?? 0
        y: root.clockArea?.y ?? 0
        width: root.clockArea?.w ?? 0
        height: root.clockArea?.h ?? 0
        radius: Styling.radius(4)
        color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.1)
        border.width: 2
        border.color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.7)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: Icons.clock + "  " + I18n.t("desktop.widgets.clock_area")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: Colors.tertiary
        }
    }
}
