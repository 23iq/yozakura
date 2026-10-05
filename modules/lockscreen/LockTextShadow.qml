import QtQuick
import QtQuick.Effects
import qs.modules.theme

// Soft shadow (or light halo) for bare text drawn straight over the wallpaper.
MultiEffect {
    shadowEnabled: true
    shadowColor: Colors.shadow
    shadowOpacity: 0.6
    shadowBlur: 0.6
    shadowVerticalOffset: 1
    blurMax: 24
}
