import QtQuick
import qs.modules.theme
import "../Ui.js" as Ui

// A wallpaper-like backdrop for screen mockups, tinted by the palette.
Rectangle {
    id: root

    radius: Math.min(Styling.radius(0), 14)
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0
            color: Ui.mix(Colors.surfaceContainerLow, Colors.primaryContainer, 0.35)
        }
        GradientStop {
            position: 1
            color: Ui.mix(Colors.surfaceContainerLow, Colors.tertiaryContainer, 0.45)
        }
    }

    Rectangle {
        x: parent.width * 0.55
        y: parent.height * 0.25
        width: parent.width * 0.7
        height: width
        radius: width / 2
        color: Ui.alpha(Colors.primary, 0.12)
    }
}
