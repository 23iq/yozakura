import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

MultiEffect {
    shadowEnabled: true
    shadowHorizontalOffset: Lighting.shadowXOffset
    shadowVerticalOffset: Lighting.shadowYOffset
    // Glass shadow softness widens the blur above the preset's amount.
    shadowBlur: Math.min(1, Lighting.shadowBlur * Glass.shadowScale)
    shadowColor: Lighting.shadowColor
    shadowOpacity: Lighting.shadowOpacity
}
