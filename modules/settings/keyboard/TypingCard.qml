import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.displays
import "../Ui.js" as Ui

// Key repeat sliders plus a field to try them out.
KeyboardCard {
    id: root

    property int repeatRate: 25
    property int repeatDelay: 600

    signal rateMoved(int value)
    signal delayMoved(int value)

    icon: "timer"
    title: I18n.t("prefs.keyboard.typing")
    subtitle: I18n.t("prefs.keyboard.typing.desc")

    DisplayRow {
        width: parent.width
        separator: false
        label: I18n.t("prefs.keyboard.repeat_rate")
        hint: I18n.t("prefs.keyboard.repeat_rate.desc")
        SliderControl {
            objectName: "rateSlider"
            width: parent.width
            from: 1
            to: 100
            value: root.repeatRate
            unit: "/s"
            onMoved: v => root.rateMoved(Math.round(v))
        }
    }

    DisplayRow {
        width: parent.width
        label: I18n.t("prefs.keyboard.repeat_delay")
        hint: I18n.t("prefs.keyboard.repeat_delay.desc")
        SliderControl {
            objectName: "delaySlider"
            width: parent.width
            from: 100
            to: 2000
            stepSize: 50
            value: root.repeatDelay
            unit: "ms"
            onMoved: v => root.delayMoved(Math.round(v))
        }
    }

    Item {
        width: parent.width
        height: 106
        Rectangle {
            x: 20
            width: parent.width - 40
            height: 1
            color: Ui.alpha(Colors.outlineVariant, 0.45)
        }
        Text {
            x: 20
            y: 18
            text: I18n.t("prefs.keyboard.try")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
            color: Colors.overSurfaceVariant
        }
        TryTypingField {
            x: 20
            y: 40
            width: parent.width - 40
        }
    }
}
