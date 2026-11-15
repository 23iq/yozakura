pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "SceneModel.js" as SceneModel

// Home tile scene of Devices: live gauges of what the machine has now, as
// rings with their icon inside and the reading under them (SceneModel.gauges):
// the battery, the Wi-Fi signal (or the cable), the volume, Bluetooth and
// how many devices are on it. As many as the room holds, in that order.
Item {
    id: scene

    required property Card tile

    readonly property int btConnected: typeof BluetoothService.connectedDevices === "number" ? BluetoothService.connectedDevices : (BluetoothService.friendlyDeviceList || []).filter(d => d && d.connected).length
    readonly property var gauges: SceneModel.gauges({
        "battery": {
            "available": Battery.available === true,
            "percent": Number(Battery.percentage) || 0,
            "charging": Battery.isCharging === true
        },
        "network": {
            "name": NetworkService.networkName || "",
            "strength": Number(NetworkService.networkStrength) || 0,
            "ethernet": NetworkService.ethernet === true
        },
        "volume": Audio.sink ? Number(Audio.sink?.audio?.volume ?? -1) : -1,
        "muted": Audio.sink?.audio?.muted === true,
        "bluetooth": {
            "enabled": BluetoothService.enabled === true,
            "connected": scene.btConnected
        }
    }, Icons)
    // a gauge's column and how many fit
    readonly property real minCell: Space.px(36)
    readonly property int count: Math.max(1, Math.min(scene.gauges.length, Math.floor((scene.width + Space.s) / (scene.minCell + Space.s))))
    readonly property real cell: (scene.width - Space.s * (scene.count - 1)) / scene.count
    readonly property real ring: Math.max(Space.l, Math.min(scene.cell, scene.height - caption.height - Space.xs, Space.px(64)))

    Component.onCompleted: {
        if (typeof BluetoothService.initialize === "function")
            BluetoothService.initialize();
    }

    KitText {
        id: caption
        visible: false
        role: "caption"
        text: "0"
    }

    Row {
        anchors.centerIn: parent
        spacing: Space.s
        Repeater {
            model: scene.gauges.slice(0, scene.count)
            delegate: Column {
                id: gauge
                required property var modelData
                width: scene.cell
                spacing: Space.xs
                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: scene.ring
                    height: scene.ring
                    value: gauge.modelData.value
                    thickness: Math.max(Space.stroke, Math.round(scene.ring * 0.08))
                    color: gauge.modelData.id === "battery" ? Type.load(1 - gauge.modelData.value) : Type.progress
                    Icon {
                        icon: gauge.modelData.icon
                        size: Math.round(scene.ring * 0.4)
                        tone: gauge.modelData.value > 0 ? "text" : "muted"
                    }
                }
                KitText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"
                    color: Type.secondary
                    // a dash where there is no reading (off, no signal)
                    text: gauge.modelData.text !== "" ? gauge.modelData.text : "–"
                    elide: Text.ElideRight
                }
            }
        }
    }
}
