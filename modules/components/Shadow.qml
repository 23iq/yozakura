import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

MultiEffect {
    shadowEnabled: true
    shadowHorizontalOffset: Config.theme.shadowXOffset
    shadowVerticalOffset: Config.theme.shadowYOffset
    // Glass shadow softness widens the blur above the preset's amount.
    shadowBlur: Math.min(1, Config.theme.shadowBlur * Glass.shadowScale)
    shadowColor: Config.resolveColor(Config.theme.shadowColor)
    shadowOpacity: Config.theme.shadowOpacity
}
