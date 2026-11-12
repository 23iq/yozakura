pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Assistant: two chat bubbles, yours and the answer.
Item {
    id: scene

    required property Card tile

    Mark {
        id: ask
        width: Math.min(scene.width, askText.implicitWidth + Space.l * 2)
        height: askText.implicitHeight + Space.m * 2
        radius: Look.radius("box", height)
        color: Look.raisedFill(false)
        KitText {
            id: askText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, scene.width - Space.l * 2)
            role: "body"
            elide: Text.ElideRight
            text: I18n.t("prefs.home.chat_ask")
        }
    }
    Mark {
        anchors.right: parent.right
        y: ask.height + Space.s
        width: answer.implicitWidth + Space.l * 2
        height: answer.implicitHeight + Space.m * 2
        radius: height / 2
        color: Type.accent
        Row {
            id: answer
            anchors.centerIn: parent
            spacing: Space.xs
            Icon {
                icon: Icons.sparkle
                role: "body"
                tone: "accentInk"
            }
            KitText {
                role: "body"
                font.weight: Font.DemiBold
                color: Colors.overPrimary
                text: I18n.t("prefs.home.chat_answer")
            }
        }
    }
}
