import QtQuick
import QtQuick.Effects

// Soft halo under clock ink (CSS text-shadow equivalent): one blurred,
// slightly dropped shadow in a theme role colour.
MultiEffect {
    // Blur radius and downward offset, in pixels.
    property real radius: 48
    property real drop: 6

    autoPaddingEnabled: true
    shadowEnabled: true
    shadowBlur: 1.0
    blurMax: Math.max(1, Math.min(64, Math.round(radius)))
    shadowHorizontalOffset: 0
    shadowVerticalOffset: drop
}
