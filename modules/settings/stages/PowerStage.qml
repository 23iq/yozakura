pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the Power page: the battery as a big ring (charge, charging or
// time left; a plug on a desktop) and the three power profiles as big
// tiles, the current one lit. A click on a tile switches the profile at
// once (PowerProfileClient; a live system setting, not on the undo
// history). Battery saver beside the stage greys the ring's arc.
Stage {
    id: stage
    objectName: "powerStage"

    readonly property bool battery: Battery.available === true
    readonly property bool charging: Battery.isCharging === true
    readonly property string toFull: String(Battery.timeToFull || "")
    readonly property string toEmpty: String(Battery.timeToEmpty || "")
    readonly property real charge: stage.battery ? Battery.percentage : 100
    readonly property bool saver: SettingsStore.get("performance.batterySaver") === true
    readonly property var profiles: [
        {
            "id": "power-saver",
            "icon": Icons.powerSave,
            "label": "prefs.power.profile.saver"
        },
        {
            "id": "balanced",
            "icon": Icons.balanced,
            "label": "prefs.power.profile.balanced"
        },
        {
            "id": "performance",
            "icon": Icons.performance,
            "label": "prefs.power.profile.performance"
        }
    ]
    // the profile just clicked shows at once; the service confirms it
    property string picked: ""
    readonly property string profile: stage.picked !== "" ? stage.picked : String(PowerProfileClient.currentProfile || "")
    readonly property bool profilesOn: PowerProfileClient.isAvailable === true

    Connections {
        target: PowerProfileClient
        function onCurrentProfileChanged() {
            stage.picked = "";
        }
    }

    stageHeight: Space.px(300)

    Row {
        anchors.centerIn: parent
        spacing: Math.round(stage.width * 0.07)

        Item {
            id: gauge
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(stage.height * 0.76)
            height: gauge.width

            Ring {
                id: ring
                objectName: "powerRing"
                anchors.fill: parent
                thickness: Space.l
                value: stage.charge / 100
                color: stage.saver ? Type.secondary : (stage.charge <= 15 && !stage.charging ? Type.danger : Type.progress)
            }
            Column {
                anchors.centerIn: parent
                width: ring.width * 0.7
                spacing: Space.xs
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: !stage.battery ? Icons.plug : (stage.charging ? Icons.batteryCharging : Icons.batteryHigh)
                    role: "title"
                    tone: "secondary"
                }
                KitText {
                    objectName: "powerPercent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "display"
                    text: stage.battery ? Math.round(stage.charge) + "%" : I18n.t("prefs.power.plugged")
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "secondary"
                    visible: text !== ""
                    text: !stage.battery ? "" : stage.charging ? (stage.toFull !== "" ? I18n.t("prefs.power.until_full").replace("%1", stage.toFull) : I18n.t("prefs.power.charging")) : (stage.toEmpty !== "" ? I18n.t("prefs.power.left").replace("%1", stage.toEmpty) : "")
                }
            }
            StageSpot {
                keys: ["performance.batterySaver"]
                spread: Space.s
                cornerRadius: ring.width / 2
            }
        }

        Row {
            id: tiles
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.m
            readonly property real tileW: Math.round(stage.width * 0.17)

            Repeater {
                model: stage.profiles
                delegate: Tile {
                    id: tile
                    required property var modelData
                    objectName: "powerProfile:" + modelData.id
                    width: tiles.tileW
                    height: Math.round(tiles.tileW * 1.35)
                    vertical: true
                    enabled: stage.profilesOn
                    opacity: enabled ? 1 : 0.5
                    icon: modelData.icon
                    text: I18n.t(modelData.label)
                    active: stage.profile === modelData.id
                    onClicked: {
                        stage.picked = tile.modelData.id;
                        PowerProfileClient.setProfile(tile.modelData.id);
                    }
                }
            }
        }
    }
}
