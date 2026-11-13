pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../connect/ConnectModel.js" as ConnectModel

// The Network page's band (list form): where you are connected - the
// signal as four bars that grow, the network's name and band / security,
// or the wire - and Wi-Fi itself as one big tile that turns it on and off.
Stage {
    id: band
    objectName: "networkBand"

    readonly property bool wifiOn: NetworkService.wifiEnabled === true
    readonly property bool wired: NetworkService.ethernet === true
    readonly property var current: NetworkService.active ?? null
    readonly property string name: String(NetworkService.networkName || "")
    readonly property int level: band.wifiOn && band.name !== "" ? ConnectModel.bars(NetworkService.networkStrength) : 0

    stageHeight: Space.px(150)

    Row {
        x: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xl

        // the signal: four bars, lit up to its strength
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs
            visible: !band.wired
            Repeater {
                model: 4
                delegate: Mark {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: Space.m
                    height: Space.l + index * Space.m
                    radius: Space.xs
                    color: index < band.level ? Type.accent : Type.track
                }
            }
        }
        Icon {
            visible: band.wired
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.ethernet
            size: Space.controlM
            tone: "accent"
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs
            KitText {
                objectName: "networkName"
                role: "display"
                text: band.wired ? I18n.t("prefs.net.wired") : (band.name !== "" ? band.name : I18n.t(band.wifiOn ? "prefs.net.not_connected" : "prefs.net.wifi_off"))
            }
            KitText {
                role: "secondary"
                visible: text !== ""
                text: band.wired ? "" : (band.current ? ConnectModel.wifiLine(band.current, k => I18n.t(k)) : "")
            }
        }
    }

    Tile {
        objectName: "wifiTile"
        anchors.right: parent.right
        anchors.rightMargin: Space.xxl
        anchors.verticalCenter: parent.verticalCenter
        width: Space.controlXL * 2
        icon: band.wifiOn ? Icons.wifiHigh : Icons.wifiOff
        text: I18n.t("prefs.net.wifi")
        subtext: I18n.t(band.wifiOn ? "prefs.net.on" : "prefs.net.off")
        active: band.wifiOn
        onClicked: NetworkService.enableWifi(!band.wifiOn)
    }
}
