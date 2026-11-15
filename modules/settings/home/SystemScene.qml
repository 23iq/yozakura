pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Home tile scene of System: the sakura and the version you run, with the
// update channel under it; a ready update lights a badge on the flower.
Item {
    id: scene

    required property Card tile

    readonly property string version: String(UpdateService.currentVersion || "")
    readonly property bool updateReady: UpdateService.updateAvailable === true
    readonly property string channel: String(UpdateService.channel || "stable")
    readonly property real mark: Math.round(Math.max(Space.l, Math.min(scene.height, Space.controlL) * 0.82))

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.m

        Item {
            width: scene.mark
            height: scene.mark
            Image {
                id: flower
                anchors.fill: parent
                visible: false
                source: Qt.resolvedUrl("../../../assets/yozakura/yozakura-icon.svg")
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            MultiEffect {
                anchors.fill: flower
                source: flower
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Type.accent
            }
            // an update is ready
            Mark {
                visible: scene.updateReady
                anchors.right: parent.right
                anchors.top: parent.top
                width: Math.round(scene.mark * 0.42)
                height: width
                color: Type.accent
                border.width: Space.hairline * 2
                border.color: Look.cardFill(false)
                Icon {
                    anchors.centerIn: parent
                    icon: Icons.downloadSimple
                    size: Math.round(parent.height * 0.6)
                    tone: "accentInk"
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, scene.width - scene.mark - Space.m)
            KitText {
                width: parent.width
                role: "title"
                font.features: {
                    "tnum": 1
                }
                text: scene.version !== "" ? scene.version : "–"
                elide: Text.ElideRight
            }
            KitText {
                width: parent.width
                role: "caption"
                color: Type.secondary
                text: I18n.t("prefs.updates.channel_" + scene.channel)
                elide: Text.ElideRight
            }
        }
    }
}
