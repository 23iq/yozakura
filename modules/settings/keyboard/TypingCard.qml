import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.displays
import "../Ui.js" as Ui
import qs.modules.components.kit

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
            to: 200
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
        Divider {
            x: Look.rowInset
            width: parent.width - Look.rowInset * 2
        }
        KitText {
            role: "secondary"
            x: Look.rowInset
            y: 18
            text: I18n.t("prefs.keyboard.try")
            font.weight: Font.DemiBold
        }
        TryTypingField {
            x: Look.rowInset
            y: 40
            width: parent.width - Look.rowInset * 2
        }
    }
}
