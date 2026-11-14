import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Night light (NightLightClient, live: no Apply): a switch and the warmth
// as one slider with Warmer and Cooler at its ends (the card's heading
// shows the temperature). Warmer = a lower colour temperature.
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

    // the warmth: one slider, Warmer and Cooler at its ends; greyed out
    // (and still) while night light is off
    Column {
        objectName: "nightWarmthBlock"
        width: root.width
        spacing: Space.s
        enabled: root.on
        opacity: root.on ? 1 : 0.38
        Behavior on opacity {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
            }
        }

        KitText {
            width: parent.width
            role: "secondary"
            text: I18n.t("prefs.displays.warmth")
        }
        Item {
            width: parent.width
            height: Math.max(warmth.implicitHeight, warmer.implicitHeight)
            KitText {
                id: warmer
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.secondary
                text: I18n.t("prefs.displays.warmer")
            }
            LineSlider {
                id: warmth
                objectName: "nightWarmth"
                anchors.left: warmer.right
                anchors.leftMargin: Space.s
                anchors.right: cooler.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                from: root.warmest
                to: root.coolest
                step: 100
                value: root.temp
                showValue: false
                Accessible.name: I18n.t("prefs.displays.warmth")
                onMoved: v => NightLightClient.setTemperature(Math.round(v / 100) * 100)
            }
            KitText {
                id: cooler
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.secondary
                text: I18n.t("prefs.displays.cooler")
            }
        }
    }
}
