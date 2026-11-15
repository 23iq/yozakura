pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the Power page: the battery as a big ring (charge, charging or
// time left; a plug on a desktop) and the three power profiles as one
// segmented choice, the current one lit. A click switches the profile at
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
    // a narrow stage (a pane beside the cards): the gauge over the profiles,
    // unless the page gives it less than that needs (a short window): then
    // side by side, the gauge as tall as the stage allows
    readonly property bool slim: stage.width > 0 && stage.width < Space.px(640)
    readonly property real stackedGauge: Math.round(Math.min(stage.width * 0.4, Space.px(170)))
    readonly property real stackedHeight: Math.round(stage.stackedGauge + Space.l + tiles.height + Space.l * 2)
    readonly property bool short: stage.height > 0 && stage.height + 1 < stage.stackedHeight
    readonly property bool narrow: stage.slim && !stage.short
    readonly property real gaugeSize: stage.narrow ? stage.stackedGauge : Math.round(stage.height * 0.76)
    // the charge line under the percentage (or over the profiles)
    readonly property string timeText: !stage.battery ? "" : stage.charging ? (stage.toFull !== "" ? I18n.t("prefs.power.until_full").replace("%1", stage.toFull) : I18n.t("prefs.power.charging")) : (stage.toEmpty !== "" ? I18n.t("prefs.power.left").replace("%1", stage.toEmpty) : "")
    // the ring holds the icon, the display-size charge and the time left
    readonly property bool ringRoomy: stage.gaugeSize >= Space.px(190)
    readonly property real preferredHeight: stage.slim ? stage.stackedHeight : 0

    Grid {
        anchors.centerIn: parent
        columns: stage.narrow ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        rowSpacing: Space.l
        columnSpacing: Math.round(stage.width * 0.07)

        Item {
            id: gauge
            width: stage.gaugeSize
            height: gauge.width

            Ring {
                id: ring
                objectName: "powerRing"
                anchors.fill: parent
                // (a small ring keeps its hole)
                thickness: Math.min(Space.l, Math.round(gauge.width * 0.12))
                value: stage.charge / 100
                color: stage.saver ? Type.secondary : (stage.charge <= 15 && !stage.charging ? Type.danger : Type.progress)
            }
            // the charge in the ring; the icon and the time left join it
            // only where the ring has room for them (else the time left
            // sits over the profiles)
            Column {
                id: inside
                readonly property real room: ring.width - ring.thickness * 2 - Space.s * 2
                anchors.centerIn: parent
                width: inside.room
                spacing: Space.xs
                Icon {
                    id: glyph
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: stage.ringRoomy
                    icon: !stage.battery ? Icons.plug : (stage.charging ? Icons.batteryCharging : Icons.batteryHigh)
                    role: "title"
                    tone: "secondary"
                }
                KitText {
                    objectName: "powerPercent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: stage.ringRoomy ? "display" : "title"
                    text: stage.battery ? Math.round(stage.charge) + "%" : I18n.t("prefs.power.plugged")
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, inside.room)
                    role: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: stage.ringRoomy && text !== ""
                    text: stage.timeText
                }
            }
            StageSpot {
                keys: ["performance.batterySaver"]
                spread: Space.s
                cornerRadius: ring.width / 2
            }
        }

        // the profiles: one exclusive choice in the shared segmented
        // style (the accent marks the current one only); the time left
        // over them when the ring has no room for it
        Column {
            spacing: Space.s
            KitText {
                objectName: "powerTimeLeft"
                anchors.horizontalCenter: parent.horizontalCenter
                role: "secondary"
                visible: !stage.ringRoomy && text !== ""
                text: stage.timeText
            }
            Segmented {
                id: tiles
                objectName: "powerProfiles"
                enabled: stage.profilesOn
                opacity: enabled ? 1 : 0.5
                focusable: true
                model: stage.profiles.map(p => ({
                            "name": "powerProfile:" + p.id,
                            "icon": p.icon,
                            "text": I18n.t(p.label)
                        }))
                currentIndex: stage.profiles.findIndex(p => p.id === stage.profile)
                onActivated: i => {
                    const id = stage.profiles[i].id;
                    stage.picked = id;
                    PowerProfileClient.setProfile(id);
                }
            }
        }
    }
}
