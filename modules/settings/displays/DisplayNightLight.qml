import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Night light (NightLightClient, live: no Apply): a switch and the warmth
// as a slider over a strip that runs from candle to daylight, the chosen
// warmth marked on it. Warmer = a lower colour temperature.
Column {
    id: root

    readonly property int coolest: 6500
    readonly property int warmest: 2500
    readonly property bool on: NightLightClient.active === true
    readonly property int temp: Number(NightLightClient.temp || 4500)

    spacing: Space.m

    Item {
        width: root.width
        height: toggle.height
        Icon {
            id: moon
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.nightLight
            role: "body"
            tone: root.on ? "accent" : "muted"
        }
        KitText {
            anchors.left: moon.right
            anchors.leftMargin: Space.m
            anchors.right: toggle.left
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            elide: Text.ElideRight
            text: I18n.t("prefs.displays.night_on")
        }
        Switch {
            id: toggle
            objectName: "nightToggle"
            anchors.right: parent.right
            checked: root.on
            onToggled: v => NightLightClient.setEnabled(v)
        }
    }

    // candle -> daylight
    Mark {
        width: root.width
        height: Space.s
        opacity: root.on ? 1 : 0.4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Colors.tertiary
            }
            GradientStop {
                position: 1
                color: Colors.overBackground
            }
        }
    }

    LineSlider {
        objectName: "nightWarmth"
        width: root.width
        enabled: root.on
        from: root.warmest
        to: root.coolest
        step: 100
        value: root.temp
        showValue: true
        valueText: root.temp + " K"
        onMoved: v => NightLightClient.setTemperature(Math.round(v / 100) * 100)
    }
}
