pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "../../services/ai/Providers.js" as Providers

// Home tile scene of Assistant: a short chat, your question on the right in
// the accent's tone, the answer on the left beside the logo of the
// provider that answers now (ai.defaultModel "provider:model"; the
// assistant's sparkle without one). Off: the chat fades back.
Item {
    id: scene

    required property Card tile

    readonly property bool aiOn: SettingsStore.get("ai.enabled") !== false
    readonly property string modelId: String(SettingsStore.get("ai.defaultModel") || "")
    readonly property var provider: scene.modelId.indexOf(":") > 0 ? Providers.PROVIDERS[scene.modelId.slice(0, scene.modelId.indexOf(":"))] || null : null
    readonly property string logo: scene.provider && scene.provider.icon ? scene.provider.icon : ""
    readonly property real bubbleH: Math.round(Math.max(Space.l, Math.min(Space.controlS, (scene.height - Space.s) / 2.2)))
    readonly property real avatar: Math.round(scene.bubbleH * 0.9)

    opacity: scene.aiOn ? 1 : 0.4

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Space.s

        // the question
        Mark {
            anchors.right: parent.right
            width: Math.round(parent.width * 0.6)
            height: scene.bubbleH
            radius: Look.radius("surface", height)
            color: Look.tonal(Type.accent)
            Mark {
                x: Space.s
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Space.s * 2
                height: Math.max(Space.xs, Math.round(parent.height * 0.18))
                color: Type.accent
                opacity: 0.7
            }
        }

        // the answer, beside who gives it
        Item {
            width: parent.width
            height: scene.bubbleH * 1.3
            Mark {
                id: face
                anchors.bottom: parent.bottom
                width: scene.avatar
                height: scene.avatar
                color: Look.raisedFill(false)
                border.width: Space.hairline
                border.color: Type.hairline
                Image {
                    id: logoImage
                    anchors.centerIn: parent
                    width: Math.round(face.width * 0.6)
                    height: width
                    visible: false
                    source: scene.logo ? Qt.resolvedUrl("../../../assets/aiproviders/" + scene.logo) : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
                MultiEffect {
                    anchors.fill: logoImage
                    visible: scene.logo !== ""
                    source: logoImage
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Type.text
                }
                Icon {
                    anchors.centerIn: parent
                    visible: scene.logo === ""
                    icon: Icons.sparkle
                    size: Math.round(face.height * 0.56)
                    tone: "accent"
                }
            }
            Mark {
                x: face.width + Space.s
                width: Math.min(parent.width - x, Math.round(parent.width * 0.78))
                height: parent.height
                radius: Look.radius("surface", scene.bubbleH)
                color: Look.raisedFill(false)
                border.width: Space.hairline
                border.color: Type.hairline
                Column {
                    x: Space.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Space.s * 2
                    spacing: Space.xs
                    Repeater {
                        model: [0.9, 0.62]
                        delegate: Mark {
                            required property real modelData
                            width: parent.width * modelData
                            height: Math.max(Space.xs, Math.round(scene.bubbleH * 0.16))
                            color: Type.track
                        }
                    }
                }
            }
        }
    }
}
