pragma ComponentBehavior: Bound
import QtQuick

// One brush stroke that fades out at both ends, thicker with more windows.
IndicatorBase {
    id: root

    size: 3
    readonly property color clear: Qt.rgba(tint.r, tint.g, tint.b, 0)

    mark: Rectangle {
        width: root.vertical ? root.across : root.cell * 0.5
        height: root.vertical ? root.cell * 0.5 : root.across
        radius: Math.min(width, height) / 2
        gradient: Gradient {
            orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop {
                position: 0
                color: root.clear
            }
            GradientStop {
                position: 0.5
                color: root.tint
            }
            GradientStop {
                position: 1
                color: root.clear
            }
        }
    }
}
